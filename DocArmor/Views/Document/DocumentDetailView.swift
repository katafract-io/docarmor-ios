import SwiftUI

struct DocumentDetailView: View {
    let document: Document

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var decryptedImages: [UIImage] = []
    @State private var currentPageIndex = 0
    @State private var isLoading = true
    @State private var decryptError: String?
    @State private var showingPresentMode = false
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // MARK: Page Carousel
                pageCarousel
                    .frame(height: 280)

                // MARK: Metadata
                VStack(alignment: .leading, spacing: 20) {
                    // Type + Category
                    HStack {
                        Label(document.documentType.rawValue, systemImage: document.documentType.systemImage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Label(document.category.rawValue, systemImage: document.category.systemImage)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(document.category.color.opacity(0.12))
                            .foregroundStyle(document.category.color)
                            .clipShape(Capsule())
                    }

                    // Expiration
                    if let expiry = document.expirationDate {
                        ExpirationRow(expirationDate: expiry, isExpired: document.isExpired, daysUntilExpiry: document.daysUntilExpiry)
                    }

                    // Notes
                    if !document.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(document.notes)
                                .font(.body)
                        }
                    }

                    // Added date
                    Text("Added \(document.createdAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(20)
            }
        }
        .navigationTitle(document.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Present Mode
                Button(action: { showingPresentMode = true }) {
                    Image(systemName: "rectangle.expand.vertical")
                }
                .disabled(decryptedImages.isEmpty)

                Menu {
                    Button(action: { showingEditSheet = true }) {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(action: shareCurrentPage) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .disabled(decryptedImages.isEmpty)
                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            await decryptPages()
        }
        .fullScreenCover(isPresented: $showingPresentMode) {
            PresentModeView(images: decryptedImages, initialIndex: currentPageIndex, documentName: document.name)
        }
        .sheet(isPresented: $showingEditSheet) {
            AddDocumentView(editingDocument: document)
        }
        .sheet(isPresented: $showingShareSheet) {
            ActivityViewController(activityItems: shareItems)
        }
        .alert("Delete Document?", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) { deleteDocument() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete \"\(document.name)\" and all its pages. This cannot be undone.")
        }
    }

    // MARK: - Page Carousel

    private var pageCarousel: some View {
        ZStack {
            Color(.systemGroupedBackground)

            if isLoading {
                ProgressView()
            } else if let error = decryptError {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.lock.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else if decryptedImages.isEmpty {
                Image(systemName: "doc.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tertiary)
            } else {
                TabView(selection: $currentPageIndex) {
                    ForEach(decryptedImages.indices, id: \.self) { i in
                        Image(uiImage: decryptedImages[i])
                            .resizable()
                            .scaledToFit()
                            .padding(12)
                            .tag(i)
                    }
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
        }
    }

    // MARK: - Decrypt

    private func decryptPages() async {
        isLoading = true
        decryptError = nil

        do {
            let key = try VaultKey.load()
            let pages = document.sortedPages

            var images: [UIImage] = []
            for page in pages {
                let jpegData = try await Task.detached(priority: .userInitiated) {
                    try EncryptionService.decrypt(
                        encryptedData: page.encryptedImageData,
                        nonce: page.nonce,
                        using: key
                    )
                }.value
                if let image = UIImage(data: jpegData) {
                    images.append(image)
                }
            }
            decryptedImages = images
        } catch {
            decryptError = "Could not decrypt document: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Share

    private func shareCurrentPage() {
        guard currentPageIndex < decryptedImages.count else { return }
        shareItems = [decryptedImages[currentPageIndex]]
        showingShareSheet = true
    }

    // MARK: - Delete

    private func deleteDocument() {
        ExpirationService.cancelReminder(for: document)
        modelContext.delete(document)
        dismiss()
    }
}

// MARK: - Supporting Views

struct ExpirationRow: View {
    let expirationDate: Date
    let isExpired: Bool
    let daysUntilExpiry: Int?

    private var color: Color {
        if isExpired { return .red }
        if let days = daysUntilExpiry, days <= 30 { return .orange }
        return .green
    }

    private var label: String {
        if isExpired { return "Expired \(expirationDate.formatted(date: .abbreviated, time: .omitted))" }
        guard let days = daysUntilExpiry else { return "Expires \(expirationDate.formatted(date: .abbreviated, time: .omitted))" }
        if days == 0 { return "Expires today" }
        return "Expires in \(days) days (\(expirationDate.formatted(date: .abbreviated, time: .omitted)))"
    }

    var body: some View {
        Label(label, systemImage: isExpired ? "exclamationmark.circle.fill" : "calendar")
            .font(.subheadline)
            .foregroundStyle(color)
    }
}

/// UIKit share sheet wrapper
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        DocumentDetailView(document: {
            let doc = Document(name: "John's License", documentType: .driversLicense)
            return doc
        }())
    }
    .modelContainer(for: [Document.self, DocumentPage.self], inMemory: true)
}
