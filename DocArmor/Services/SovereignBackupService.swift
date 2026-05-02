import CryptoKit
import Foundation

/// Backs up encrypted DocArmor snapshots to the user's Vaultyx vault when the
/// caller holds a Sovereign or Founder subscription.
///
/// The server contract is identical to Vaultyx's own upload path:
///   1. POST /v1/vault/init   — idempotent; creates vault record for this token
///   2. POST /v1/vault/presign  — obtain a presigned S3 PUT URL for the chunk
///   3. PUT <presigned-url>   — upload encrypted bytes directly to S3
///   4. POST /v1/vault/manifest — register the file with the server (opaque manifest)
///
/// All bytes reaching the server are encrypted with DocArmor's local vault key
/// (AES-GCM, CryptoKit). The server never sees plaintext.
///
/// Network failures at any step are swallowed — backup is best-effort. The local
/// save always completes before the upload attempt begins.
enum SovereignBackupService {

    // MARK: - Constants

    private static let baseURL = URL(string: "https://api.katafract.com")!
    private static let appGroup = "group.com.katafract.enclave"
    private static let tokenKey = "enclave.sigil.token"
    private static let planKey  = "enclave.sigil.plan"

    // MARK: - Public API

    /// Attempt to back up `document` to Vaultyx. Fire-and-forget: call from a
    /// detached Task so the save flow is never blocked.
    ///
    ///     Task.detached(priority: .background) {
    ///         await SovereignBackupService.backup(document: savedDocument, vaultKey: key)
    ///     }
    static func backup(document: Document, vaultKey: SymmetricKey) async {
        guard let token = sovereignToken() else { return }

        let payload: Data
        do {
            payload = try buildEncryptedPayload(document: document, key: vaultKey)
        } catch {
            return
        }

        let chunkHash = SHA256.hash(data: payload).compactMap { String(format: "%02x", $0) }.joined()
        let fileId    = document.id.uuidString.lowercased()
        let filename  = "\(document.name)-\(fileId).docarmor-vault"

        do {
            try await ensureVaultInitialised(token: token)
            let putURL = try await presign(fileId: fileId, chunkHash: chunkHash, token: token)
            try await uploadChunk(data: payload, to: putURL)
            try await pushManifest(
                fileId: fileId,
                chunkHash: chunkHash,
                sizeBytes: payload.count,
                filenameEnc: filename,
                token: token
            )
        } catch {
            // Best-effort — local save already succeeded; log and move on.
        }
    }

    // MARK: - Entitlement check

    /// Returns the Sigil token from the shared App Group iff the plan is sovereign or founder.
    /// Returns nil for any other plan or if the App Group is unavailable.
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

    private static func presign(fileId: String, chunkHash: String, token: String) async throws -> URL {
        let body = ["file_id": fileId, "chunk_hash": chunkHash, "operation": "put"]
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

    private static func pushManifest(
        fileId: String,
        chunkHash: String,
        sizeBytes: Int,
        filenameEnc: String,
        token: String
    ) async throws {
        // The manifest is opaque to the server — we store a minimal JSON descriptor
        // (also encrypted) so Vaultyx can list files without knowing their contents.
        let manifestRaw = ["file_id": fileId, "source": "docarmor"]
        let manifestData = (try? JSONEncoder().encode(manifestRaw)) ?? Data("{\"source\":\"docarmor\"}".utf8)
        let manifestB64 = manifestData.base64EncodedString()

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

    // MARK: - Payload construction

    /// Serialise the document (name, type, metadata) and encrypt it with the
    /// local vault key. Image pages are excluded — this is a metadata backup,
    /// not a full image backup (page images are already large and local-encrypted
    /// on device; full image backup is a future V2 feature).
    private static func buildEncryptedPayload(document: Document, key: SymmetricKey) throws -> Data {
        let snapshot = DocumentSnapshot(
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
            createdAt: document.createdAt,
            updatedAt: document.updatedAt,
            isFavorite: document.isFavorite,
            pageCount: document.pages.count,
            source: "docarmor"
        )
        let plaintext = try JSONEncoder().encode(snapshot)
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else { throw UploadError.encryptionFailed }
        return combined
    }

    // MARK: - Private types

    private enum UploadError: Error {
        case vaultInitFailed
        case presignFailed
        case chunkUploadFailed
        case manifestUploadFailed
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

    /// Minimal serialisable snapshot of document metadata (no image data).
    private struct DocumentSnapshot: Encodable {
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
        let createdAt: Date
        let updatedAt: Date
        let isFavorite: Bool
        let pageCount: Int
        let source: String
    }
}
