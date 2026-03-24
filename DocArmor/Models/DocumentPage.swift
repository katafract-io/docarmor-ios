import Foundation
import SwiftData

@Model
final class DocumentPage {
    var id: UUID
    var pageIndex: Int
    /// AES-256-GCM ciphertext with 16-byte authentication tag appended
    var encryptedImageData: Data
    /// 12-byte GCM nonce — not secret, stored alongside ciphertext
    var nonce: Data
    /// "Front", "Back", or nil for single-page documents
    var label: String?
    var document: Document?

    init(
        id: UUID = UUID(),
        pageIndex: Int,
        encryptedImageData: Data,
        nonce: Data,
        label: String? = nil
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.encryptedImageData = encryptedImageData
        self.nonce = nonce
        self.label = label
    }
}
