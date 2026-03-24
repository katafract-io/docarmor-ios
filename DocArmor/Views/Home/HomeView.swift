import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.pendingDocumentType) private var pendingDocumentType
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            VaultView(pendingDocumentType: pendingDocumentType)
                .tabItem {
                    Label("Vault", systemImage: "lock.shield.fill")
                }
                .tag(0)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(1)
        }
        .tint(.accentColor)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Document.self, DocumentPage.self], inMemory: true)
        .environment(AuthService())
        .environment(AutoLockService(authService: AuthService()))
}
