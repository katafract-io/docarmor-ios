import SwiftUI
import SwiftData

struct VaultView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Document.createdAt, order: .reverse) private var allDocuments: [Document]

    @State private var searchText = ""
    @State private var showingAddDocument = false
    @State private var navigationPath = NavigationPath()

    var pendingDocumentType: Binding<DocumentType?>
    var pendingCategory: Binding<DocumentCategory?>

    // MARK: - Computed

    private var filteredDocuments: [Document] {
        guard !searchText.isEmpty else { return allDocuments }
        return allDocuments.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.documentType.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var favorites: [Document] {
        filteredDocuments.filter { $0.isFavorite }
    }

    private var documentsByCategory: [(DocumentCategory, [Document])] {
        let nonFavorites = filteredDocuments.filter { !$0.isFavorite }
        return DocumentCategory.allCases.compactMap { category in
            let docs = nonFavorites.filter { $0.category == category }
            return docs.isEmpty ? nil : (category, docs)
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if allDocuments.isEmpty {
                    emptyStateView
                } else {
                    documentList
                }
            }
            .navigationTitle("DocArmor")
            .navigationDestination(for: Document.self) { document in
                DocumentDetailView(document: document)
            }
            .searchable(text: $searchText, prompt: "Search documents")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddDocument = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddDocument) {
                AddDocumentView()
            }
            .onChange(of: pendingDocumentType.wrappedValue) { _, type in
                guard let type else { return }
                // Navigate to first matching document for deep-link
                if let doc = allDocuments.first(where: { $0.documentType == type }) {
                    navigationPath.append(doc)
                }
                pendingDocumentType.wrappedValue = nil
            }
            .onChange(of: pendingCategory.wrappedValue) { _, category in
                guard let category else { return }
                // Navigate to the first document in the requested category (Siri intent)
                if let doc = allDocuments.first(where: { $0.category == category }) {
                    navigationPath.append(doc)
                }
                pendingCategory.wrappedValue = nil
            }
        }
    }

    // MARK: - Document List

    private var documentList: some View {
        List {
            // Favorites section
            if !favorites.isEmpty {
                Section {
                    ForEach(favorites) { doc in
                        DocumentRow(document: doc)
                            .contentShape(Rectangle())
                            .onTapGesture { navigationPath.append(doc) }
                    }
                    .onDelete { indexSet in
                        deleteDocuments(from: favorites, at: indexSet)
                    }
                } header: {
                    Label("Favorites", systemImage: "star.fill")
                        .foregroundStyle(.yellow)
                }
            }

            // Category sections
            ForEach(documentsByCategory, id: \.0) { category, docs in
                Section {
                    ForEach(docs) { doc in
                        DocumentRow(document: doc)
                            .contentShape(Rectangle())
                            .onTapGesture { navigationPath.append(doc) }
                    }
                    .onDelete { indexSet in
                        deleteDocuments(from: docs, at: indexSet)
                    }
                } header: {
                    CategoryHeader(category: category)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "lock.shield")
                .font(.system(size: 72))
                .foregroundStyle(.tint.opacity(0.7))

            VStack(spacing: 8) {
                Text("Your Vault is Empty")
                    .font(.title2.bold())
                Text("Add your important documents — driver's license,\npassport, insurance cards, and more.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: { showingAddDocument = true }) {
                Label("Add First Document", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: 280)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
    }

    // MARK: - Delete

    private func deleteDocuments(from docs: [Document], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(docs[index])
        }
    }
}

// MARK: - Supporting Views

struct CategoryHeader: View {
    let category: DocumentCategory

    var body: some View {
        Label(category.rawValue, systemImage: category.systemImage)
            .foregroundStyle(category.color)
            .font(.footnote.bold())
    }
}

struct DocumentRow: View {
    let document: Document

    var body: some View {
        HStack(spacing: 12) {
            // Doc type icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(document.category.color.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: document.documentType.systemImage)
                    .font(.system(size: 18))
                    .foregroundStyle(document.category.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(document.name)
                        .font(.body.weight(.medium))
                    if document.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }
                Text(document.documentType.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Expiration badge
            if let days = document.daysUntilExpiry {
                ExpirationBadge(daysUntilExpiry: days, isExpired: document.isExpired)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

struct ExpirationBadge: View {
    let daysUntilExpiry: Int
    let isExpired: Bool

    private var badgeColor: Color {
        if isExpired { return .red }
        if daysUntilExpiry <= 30 { return .orange }
        return .green
    }

    private var label: String {
        if isExpired { return "Expired" }
        if daysUntilExpiry <= 30 { return "\(daysUntilExpiry)d" }
        return ""
    }

    var body: some View {
        if isExpired || daysUntilExpiry <= 30 {
            Text(label)
                .font(.caption2.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(badgeColor.opacity(0.15))
                .foregroundStyle(badgeColor)
                .clipShape(Capsule())
        }
    }
}

#Preview {
    VaultView(pendingDocumentType: .constant(nil), pendingCategory: .constant(nil))
        .modelContainer(for: [Document.self, DocumentPage.self], inMemory: true)
}
