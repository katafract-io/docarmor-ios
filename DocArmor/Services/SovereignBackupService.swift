import CryptoKit
import Foundation
import SwiftData

/// Backs up and restores encrypted DocArmor documents to the user's Vaultyx vault
/// when the caller holds a Sovereign or Founder subscription.
///
/// The server contract is identical to Vaultyx's own vault path:
///   - POST /v1/vault/init            — idempotent; creates vault record for this token
///   - POST /v1/vault/presign         — presigned S3 URL for a chunk (put or get)
///   - PUT  <presigned-url>           — upload/download encrypted bytes directly to S3
///   - POST /v1/vault/manifest        — register a file (opaque, client-encrypted manifest)
///   - GET  /v1/vault/tree            — list backed-up files
///   - GET  /v1/vault/manifest/{id}   — fetch a file's opaque manifest
///   - DELETE /v1/vault/files/{id}    — soft-delete a backed-up file
///   - GET  /v1/vault/usage           — storage usage / quota
///
/// Every byte reaching the server is encrypted with DocArmor's local vault key
/// (AES-GCM, CryptoKit). The server never sees plaintext. Because the vault key is
/// device-local (Keychain, `WhenPasscodeSetThisDeviceOnly`, never exported), cloud
/// restore recovers documents onto **the same device** (e.g. after accidental
/// deletion or an iCloud device-restore that preserved the Keychain). Cross-device
/// migration uses the passphrase-based Encrypted Backup export, which carries the key.
enum SovereignBackupService {

    // MARK: - Constants

    private static let baseURL = URL(string: "https://api.katafract.com")!
    private static let appGroup = "group.com.katafract.enclave"
    private static let tokenKey = "enclave.sigil.token"
    private static let planKey  = "enclave.sigil.plan"

    /// Payload schema version. v1 = metadata-only (legacy uploads). v2 = full content (page images).
    private static let payloadFormatVersion = 2

    // MARK: - Public API — Backup

    /// Attempt to back up `document` (full content, including encrypted page images) to Vaultyx.
    /// Returns true iff all steps succeeded. Fire-and-forget from a detached Task.
    @discardableResult
    static func backup(document: Document, vaultKey: SymmetricKey) async -> Bool {
        guard let token = sovereignToken() else { return false }

        let payload: Data
        do {
            payload = try buildEncryptedPayload(document: document, key: vaultKey)
        } catch {
            return false
        }

        let chunkHash = hexDigest(of: payload)
        let fileId    = document.id.uuidString.lowercased()
        // Filename carries NO plaintext document name — only the opaque file id + a suffix
        // that lets us identify DocArmor's own files in the vault tree. The server sees no
        // plaintext (the name lives inside the AES-GCM–sealed payload).
        let filename  = "\(fileId).docarmor-vault"

        do {
            try await ensureVaultInitialised(token: token)
            let putURL = try await presign(fileId: fileId, chunkHash: chunkHash, operation: "put", token: token)
            try await uploadChunk(data: payload, to: putURL)
            try await pushManifest(
                fileId: fileId,
                chunkHash: chunkHash,
                sizeBytes: payload.count,
                filenameEnc: filename,
                token: token
            )
            return true
        } catch {
            // Best-effort — local save already succeeded.
            return false
        }
    }

    // MARK: - Public API — Restore

    struct RestoreSummary {
        var restored: Int = 0
        var skipped: Int = 0      // already present locally (matched by id)
        var failed: Int = 0       // download/decrypt/decode failure (e.g. wrong device key)
        var total: Int = 0
    }

    enum RestoreError: LocalizedError {
        case notSovereign
        case noVaultKey
        case listFailed

        var errorDescription: String? {
            switch self {
            case .notSovereign:
                return "Cloud restore requires an active Sovereign subscription signed in through the Enclave app."
            case .noVaultKey:
                return "This device's vault key is unavailable, so encrypted backups can't be decrypted here. Use an Encrypted Backup file to move documents to a new device."
            case .listFailed:
                return "Couldn't reach Vaultyx to list your backups. Check your connection and try again."
            }
        }
    }

    /// Download every backed-up document from Vaultyx and merge it into the local store.
    /// Non-destructive: documents already present locally (matched by id) are skipped, never
    /// overwritten or deleted. `onProgress` is called on the main actor as work advances.
    @MainActor
    @discardableResult
    static func restoreAll(
        into modelContext: ModelContext,
        onProgress: ((_ completed: Int, _ total: Int) -> Void)? = nil
    ) async throws -> RestoreSummary {
        guard let token = sovereignToken() else { throw RestoreError.notSovereign }

        let key: SymmetricKey
        do {
            key = try VaultKey.load()
        } catch {
            throw RestoreError.noVaultKey
        }

        let files: [TreeFile]
        do {
            files = try await listAllFiles(token: token)
        } catch {
            throw RestoreError.listFailed
        }

        // Existing document ids — restore is a merge, never a wipe.
        let existing = (try? modelContext.fetch(FetchDescriptor<Document>())) ?? []
        var existingIDs = Set(existing.map { $0.id })

        var summary = RestoreSummary()
        summary.total = files.count
        onProgress?(0, files.count)

        var completed = 0
        for file in files {
            completed += 1
            defer { onProgress?(completed, files.count) }

            guard let docID = UUID(uuidString: file.file_id) else { summary.failed += 1; continue }
            if existingIDs.contains(docID) { summary.skipped += 1; continue }

            do {
                guard let chunkHash = try await manifestChunkHash(fileId: file.file_id, token: token) else {
                    // Legacy v1 (metadata-only) backup with no chunk hash — nothing restorable.
                    // It'll be superseded by a v2 full-content backup next time the doc syncs.
                    summary.skipped += 1; continue
                }
                let getURL = try await presign(fileId: file.file_id, chunkHash: chunkHash, operation: "get", token: token)
                let bytes = try await downloadChunk(from: getURL)
                let snapshot = try decryptSnapshot(bytes, key: key)
                let document = insertDocument(from: snapshot, into: modelContext)
                // Persist per-document so the summary reflects what actually committed, and
                // reminders are only scheduled for docs that made it to disk.
                do {
                    try modelContext.save()
                    ExpirationService.scheduleReminder(for: document)
                    existingIDs.insert(docID)
                    summary.restored += 1
                } catch {
                    modelContext.rollback()
                    summary.failed += 1
                }
            } catch {
                // Most commonly a wrong-device vault key (can't decrypt). Count and continue.
                summary.failed += 1
            }
        }
        return summary
    }

    // MARK: - Public API — Delete / purge

    struct PurgeResult {
        /// Number of files successfully deleted (HTTP 2xx response).
        var deletedCount: Int = 0
        /// Number of files that failed to delete (non-2xx or network error).
        var failedCount: Int = 0
        /// true if list operation succeeded; false means we don't know how many files need deleting.
        var listSucceeded: Bool = false
        /// true if NO local errors occurred (all required local steps completed).
        var localOpsSucceeded: Bool = false
        /// If non-nil, a description of what went wrong (e.g., "No Sovereign subscription").
        var errorDescription: String?

        var partialFailure: Bool { failedCount > 0 || !listSucceeded }
    }

    /// Best-effort remote soft-delete of a document's backup. Call fire-and-forget after a local delete.
    static func deleteRemote(documentId: UUID) async {
        guard let token = sovereignToken() else { return }
        let fileId = documentId.uuidString.lowercased()
        var req = URLRequest(url: baseURL.appendingPathComponent("/v1/vault/files/\(fileId)"))
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try? await URLSession.shared.data(for: req)
    }

    /// Purge ALL of this vault's DocArmor backups and validate success. Returns a structured result.
    /// Used by Reset Vault so a key rotation doesn't leave undecryptable orphans consuming the user's Vaultyx quota.
    /// Non-2xx DELETE responses are treated as failures, not successes. If list fails, result.listSucceeded=false.
    static func purgeAllRemote() async -> PurgeResult {
        var result = PurgeResult()

        guard let token = sovereignToken() else {
            result.errorDescription = "No Sovereign subscription"
            return result
        }

        let files: [TreeFile]
        do {
            files = try await listAllFiles(token: token)
            result.listSucceeded = true
        } catch {
            // List failed — we cannot enumerate files to delete. Mark failure but return so
            // local reset can still proceed (attempting remote purge is best-effort).
            result.errorDescription = "Couldn't reach Vaultyx to list cloud backups"
            return result
        }

        // Attempt to DELETE each file and validate HTTP status.
        for file in files {
            var req = URLRequest(url: baseURL.appendingPathComponent("/v1/vault/files/\(file.file_id)"))
            req.httpMethod = "DELETE"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            do {
                let (_, response) = try await URLSession.shared.data(for: req)
                guard let http = response as? HTTPURLResponse,
                      http.statusCode == 200 || http.statusCode == 204 || http.statusCode == 404 else {
                    // Treat non-2xx (except 404, which means already deleted) as failure.
                    result.failedCount += 1
                    continue
                }
                result.deletedCount += 1
            } catch {
                // Network or URLSession error.
                result.failedCount += 1
            }
        }

        return result
    }

    // MARK: - Public API — Usage

    struct Usage { let usedBytes: Int; let quotaBytes: Int }

    /// Fetch Vaultyx storage usage/quota. Returns nil on any failure (UI treats as unavailable).
    static func fetchUsage() async -> Usage? {
        guard let token = sovereignToken() else { return nil }
        var req = URLRequest(url: baseURL.appendingPathComponent("/v1/vault/usage"))
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, response) = try? await URLSession.shared.data(for: req),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let decoded = try? JSONDecoder().decode(UsageResponse.self, from: data) else {
            return nil
        }
        return Usage(usedBytes: decoded.usage_bytes, quotaBytes: decoded.quota_bytes)
    }

    // MARK: - Entitlement check

    /// Returns the Sigil token from the shared App Group iff the plan is sovereign or founder.
    static func sovereignToken() -> String? {
        guard let defaults = UserDefaults(suiteName: appGroup) else { return nil }
        let token = defaults.string(forKey: tokenKey) ?? ""
        let plan  = (defaults.string(forKey: planKey) ?? "").lowercased()
        guard !token.isEmpty,
              plan == "sovereign" || plan == "sovereign_annual" || plan == "founder" else {
            return nil
        }
        return token
    }

    // MARK: - Upload pipeline

    private static func ensureVaultInitialised(token: String) async throws {
        var req = URLRequest(url: baseURL.appendingPathComponent("/v1/vault/init"))
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = Data("{}".utf8)
        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse,
              http.statusCode == 200 || http.statusCode == 201 else {
            throw UploadError.vaultInitFailed
        }
    }

    private static func presign(fileId: String, chunkHash: String, operation: String, token: String) async throws -> URL {
        let body = ["file_id": fileId, "chunk_hash": chunkHash, "operation": operation]
        var req = URLRequest(url: baseURL.appendingPathComponent("/v1/vault/presign"))
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UploadError.presignFailed
        }
        let decoded = try JSONDecoder().decode(PresignResponse.self, from: data)
        guard let url = URL(string: decoded.url) else { throw UploadError.presignFailed }
        return url
    }

    private static func uploadChunk(data: Data, to url: URL) async throws {
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        let (_, response) = try await URLSession.shared.upload(for: req, from: data)
        guard let http = response as? HTTPURLResponse,
              http.statusCode == 200 || http.statusCode == 204 else {
            throw UploadError.chunkUploadFailed
        }
    }

    private static func downloadChunk(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UploadError.chunkDownloadFailed
        }
        return data
    }

    private static func pushManifest(
        fileId: String,
        chunkHash: String,
        sizeBytes: Int,
        filenameEnc: String,
        token: String
    ) async throws {
        // The manifest is opaque to the server. We embed the chunk hash + format version so
        // restore is fully self-describing: GET /tree → GET /manifest/{id} → presign(get) → download.
        let descriptor = ManifestDescriptor(file_id: fileId, source: "docarmor", chunk_hash: chunkHash, v: payloadFormatVersion)
        let descriptorData = (try? JSONEncoder().encode(descriptor)) ?? Data("{\"source\":\"docarmor\"}".utf8)
        let manifestB64 = descriptorData.base64EncodedString()

        let body = ManifestUploadBody(
            file_id: fileId,
            manifest_data: manifestB64,
            filename_enc: filenameEnc,
            parent_folder_id: nil,
            size_bytes: sizeBytes,
            chunk_count: 1,
            chunk_hashes: [chunkHash]
        )

        var req = URLRequest(url: baseURL.appendingPathComponent("/v1/vault/manifest"))
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse,
              http.statusCode == 200 || http.statusCode == 201 else {
            throw UploadError.manifestUploadFailed
        }
    }

    // MARK: - Restore pipeline

    private static func listAllFiles(token: String) async throws -> [TreeFile] {
        var all: [TreeFile] = []
        var offset = 0
        let limit = 200
        while true {
            var comps = URLComponents(url: baseURL.appendingPathComponent("/v1/vault/tree"), resolvingAgainstBaseURL: false)!
            comps.queryItems = [
                URLQueryItem(name: "offset", value: String(offset)),
                URLQueryItem(name: "limit", value: String(limit)),
            ]
            var req = URLRequest(url: comps.url!)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw UploadError.treeListFailed
            }
            let decoded = try JSONDecoder().decode(TreeResponse.self, from: data)
            // Only DocArmor's own files carry the .docarmor-vault filename suffix.
            all.append(contentsOf: decoded.files.filter { $0.filename_enc.hasSuffix(".docarmor-vault") })
            offset += decoded.files.count
            if decoded.files.count < limit || offset >= decoded.count { break }
        }
        return all
    }

    /// Fetch a file's opaque manifest and extract the chunk hash needed to download it.
    private static func manifestChunkHash(fileId: String, token: String) async throws -> String? {
        var req = URLRequest(url: baseURL.appendingPathComponent("/v1/vault/manifest/\(fileId)"))
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UploadError.manifestFetchFailed
        }
        let manifest = try JSONDecoder().decode(ManifestResponse.self, from: data)
        guard let raw = Data(base64Encoded: manifest.manifest_data),
              let descriptor = try? JSONDecoder().decode(ManifestDescriptor.self, from: raw) else {
            return nil
        }
        return descriptor.chunk_hash
    }

    // MARK: - Payload construction / parsing

    /// Serialise the document — full content, including each page's AES-GCM ciphertext and nonce —
    /// then seal the whole snapshot with the local vault key.
    private static func buildEncryptedPayload(document: Document, key: SymmetricKey) throws -> Data {
        let snapshot = DocumentSnapshot(
            formatVersion: payloadFormatVersion,
            id: document.id.uuidString,
            name: document.name,
            ownerName: document.ownerName,
            documentTypeRaw: document.documentTypeRaw,
            categoryRaw: document.categoryRaw,
            notes: document.notes,
            issuerName: document.issuerName,
            identifierSuffix: document.identifierSuffix,
            lastVerifiedAt: document.lastVerifiedAt,
            renewalNotes: document.renewalNotes,
            expirationDate: document.expirationDate,
            expirationReminderDays: document.expirationReminderDays,
            createdAt: document.createdAt,
            updatedAt: document.updatedAt,
            isFavorite: document.isFavorite,
            pages: document.sortedPages.map {
                PageSnapshot(
                    id: $0.id.uuidString,
                    pageIndex: $0.pageIndex,
                    encryptedImageData: $0.encryptedImageData,
                    nonce: $0.nonce,
                    label: $0.label
                )
            },
            source: "docarmor"
        )
        let plaintext = try JSONEncoder().encode(snapshot)
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else { throw UploadError.encryptionFailed }
        return combined
    }

    private static func decryptSnapshot(_ bytes: Data, key: SymmetricKey) throws -> DocumentSnapshot {
        let box = try AES.GCM.SealedBox(combined: bytes)
        let plaintext = try AES.GCM.open(box, using: key)
        return try JSONDecoder().decode(DocumentSnapshot.self, from: plaintext)
    }

    @MainActor
    @discardableResult
    private static func insertDocument(from snapshot: DocumentSnapshot, into modelContext: ModelContext) -> Document {
        let docID = UUID(uuidString: snapshot.id) ?? UUID()
        let document = Document(
            id: docID,
            name: snapshot.name,
            ownerName: snapshot.ownerName,
            documentType: DocumentType(rawValue: snapshot.documentTypeRaw) ?? .custom,
            category: DocumentCategory(rawValue: snapshot.categoryRaw) ?? .identity,
            notes: snapshot.notes,
            issuerName: snapshot.issuerName,
            identifierSuffix: snapshot.identifierSuffix,
            lastVerifiedAt: snapshot.lastVerifiedAt,
            renewalNotes: snapshot.renewalNotes,
            expirationDate: snapshot.expirationDate,
            expirationReminderDays: snapshot.expirationReminderDays,
            isFavorite: snapshot.isFavorite
        )
        document.createdAt = snapshot.createdAt
        document.updatedAt = snapshot.updatedAt
        document.lastBackedUpAt = Date.now
        modelContext.insert(document)

        for page in (snapshot.pages ?? []) {
            let modelPage = DocumentPage(
                id: UUID(uuidString: page.id) ?? UUID(),
                pageIndex: page.pageIndex,
                encryptedImageData: page.encryptedImageData,
                nonce: page.nonce,
                label: page.label
            )
            modelPage.document = document
            modelContext.insert(modelPage)
        }

        return document
    }

    // MARK: - Helpers

    private static func hexDigest(of data: Data) -> String {
        SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Private types

    private enum UploadError: Error {
        case vaultInitFailed
        case presignFailed
        case chunkUploadFailed
        case chunkDownloadFailed
        case manifestUploadFailed
        case manifestFetchFailed
        case treeListFailed
        case encryptionFailed
    }

    private struct PresignResponse: Decodable {
        let url: String
        let expires_in: Int
    }

    private struct ManifestUploadBody: Encodable {
        let file_id: String
        let manifest_data: String
        let filename_enc: String
        let parent_folder_id: String?
        let size_bytes: Int
        let chunk_count: Int
        let chunk_hashes: [String]
    }

    private struct ManifestResponse: Decodable {
        let file_id: String
        let manifest_data: String
        let size_bytes: Int
        let chunk_count: Int
    }

    /// The (base64'd) descriptor we store inside the opaque manifest so restore is self-describing.
    /// `chunk_hash`/`v` are optional so legacy v1 (metadata-only) manifests still decode — a nil
    /// chunk_hash signals "nothing restorable" rather than throwing.
    private struct ManifestDescriptor: Codable {
        let file_id: String
        let source: String
        let chunk_hash: String?
        let v: Int?
    }

    private struct TreeResponse: Decodable {
        let files: [TreeFile]
        let count: Int
    }

    private struct TreeFile: Decodable {
        let file_id: String
        let filename_enc: String
        let size_bytes: Int
        let chunk_count: Int
    }

    private struct UsageResponse: Decodable {
        let usage_bytes: Int
        let quota_bytes: Int
    }

    /// Full serialisable snapshot of a document, including encrypted page content (v2+).
    private struct DocumentSnapshot: Codable {
        let formatVersion: Int
        let id: String
        let name: String
        let ownerName: String?
        let documentTypeRaw: String
        let categoryRaw: String
        let notes: String
        let issuerName: String
        let identifierSuffix: String
        let lastVerifiedAt: Date?
        let renewalNotes: String
        let expirationDate: Date?
        let expirationReminderDays: [Int]?
        let createdAt: Date
        let updatedAt: Date
        let isFavorite: Bool
        /// Encrypted page content. Optional so legacy v1 (metadata-only) payloads still decode.
        let pages: [PageSnapshot]?
        let source: String
    }

    private struct PageSnapshot: Codable {
        let id: String
        let pageIndex: Int
        let encryptedImageData: Data
        let nonce: Data
        let label: String?
    }
}
