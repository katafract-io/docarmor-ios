import Foundation
import CryptoKit

/// AES-256-GCM encryption/decryption for document page images.
///
/// Storage format:
/// - `encryptedImageData`: ciphertext || 16-byte authentication tag (concatenated)
/// - `nonce`: 12-byte GCM nonce (not secret; randomly generated per page)
///
/// The AES key is never passed as a stored property — callers retrieve it fresh
/// from `VaultKey.load()` for each operation.
enum EncryptionService {

    // MARK: - Encrypt

    /// Encrypt raw image data (JPEG bytes) using AES-256-GCM.
    /// - Parameters:
    ///   - plaintext: Raw JPEG data to encrypt
    ///   - key: AES-256 SymmetricKey from VaultKey.load()
    /// - Returns: Tuple of (ciphertext+tag, nonce) to store in DocumentPage
    nonisolated static func encrypt(_ plaintext: Data, using key: SymmetricKey) throws -> (encryptedData: Data, nonce: Data) {
        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(plaintext, using: key, nonce: nonce)

        // Concatenate ciphertext + 16-byte tag for storage
        let encryptedData = sealedBox.ciphertext + sealedBox.tag
        let nonceData = Data(nonce)

        return (encryptedData, nonceData)
    }

    // MARK: - Decrypt

    /// Decrypt stored ciphertext+tag using the provided nonce and key.
    /// - Parameters:
    ///   - encryptedData: Stored ciphertext with appended 16-byte authentication tag
    ///   - nonce: Stored 12-byte nonce
    ///   - key: AES-256 SymmetricKey from VaultKey.load()
    /// - Returns: Original JPEG data
    nonisolated static func decrypt(encryptedData: Data, nonce nonceData: Data, using key: SymmetricKey) throws -> Data {
        guard encryptedData.count > 16 else {
            throw EncryptionError.invalidCiphertext
        }

        let ciphertext = encryptedData.dropLast(16)
        let tag = encryptedData.suffix(16)
        let nonce = try AES.GCM.Nonce(data: nonceData)
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)

        return try AES.GCM.open(sealedBox, using: key)
    }
}

// MARK: - Errors

enum EncryptionError: LocalizedError {
    case invalidCiphertext

    var errorDescription: String? {
        switch self {
        case .invalidCiphertext:
            return "Encrypted data is too short to contain a valid authentication tag."
        }
    }
}
