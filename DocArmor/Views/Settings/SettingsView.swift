import SwiftUI
import SwiftData
import LocalAuthentication

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var auth
    @Environment(AutoLockService.self) private var autoLock
    @Query private var allDocuments: [Document]

    @State private var showingResetAlert = false
    @State private var showingResetConfirm = false
    @State private var isResetting = false

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Security
                Section("Security") {
                    Picker("Auto-Lock", selection: autoLockTimeoutBinding) {
                        ForEach(AutoLockService.Timeout.allCases) { timeout in
                            Text(timeout.displayName).tag(timeout)
                        }
                    }
                    .pickerStyle(.menu)

                    HStack {
                        Label("Biometrics", systemImage: biometryIcon)
                        Spacer()
                        Text(biometryName)
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: Vault
                Section("Vault") {
                    HStack {
                        Label("Documents", systemImage: "doc.fill")
                        Spacer()
                        Text("\(allDocuments.count)")
                            .foregroundStyle(.secondary)
                    }

                    Button(role: .destructive) {
                        showingResetAlert = true
                    } label: {
                        Label("Reset Vault", systemImage: "trash.fill")
                            .foregroundStyle(.red)
                    }
                    .disabled(isResetting)
                }

                // MARK: About
                Section("About") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Developer", systemImage: "person.fill")
                        Spacer()
                        Text("Katafract LLC")
                            .foregroundStyle(.secondary)
                    }

                    NavigationLink(destination: PrivacyPolicyView()) {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                    }
                }

                // MARK: Privacy Statement
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("100% Local Storage", systemImage: "iphone")
                            .font(.caption.bold())
                        Text("Your documents never leave this device. DocArmor makes zero network connections and has no server infrastructure.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Settings")
            .alert("Reset Vault?", isPresented: $showingResetAlert) {
                Button("Reset Everything", role: .destructive) {
                    showingResetConfirm = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete ALL documents and the encryption key. Your data will be unrecoverable. This cannot be undone.")
            }
            .confirmationDialog("Are you absolutely sure?", isPresented: $showingResetConfirm, titleVisibility: .visible) {
                Button("Delete Everything Forever", role: .destructive) {
                    Task { await resetVault() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All \(allDocuments.count) document(s) will be permanently destroyed.")
            }
        }
    }

    // MARK: - Reset Vault

    private func resetVault() async {
        isResetting = true
        ExpirationService.cancelAllReminders()

        // Delete all SwiftData records
        for doc in allDocuments {
            modelContext.delete(doc)
        }

        // Explicitly save before touching the Keychain. SwiftData batches deletes
        // and may not flush until the next auto-save window; if the app crashes
        // after VaultKey.delete() but before the context saves, stale encrypted
        // records remain — now undecryptable with the new key.
        try? modelContext.save()

        // Delete vault encryption key — encrypted data is now unrecoverable garbage
        try? VaultKey.delete()

        // Generate a fresh key for any future use
        _ = try? VaultKey.generate()

        auth.lock()
        isResetting = false
    }

    // MARK: - Helpers

    private var biometryIcon: String {
        switch auth.biometryType {
        case .faceID:  return "faceid"
        case .touchID: return "touchid"
        default:       return "lock.fill"
        }
    }

    private var autoLockTimeoutBinding: Binding<AutoLockService.Timeout> {
        Binding(
            get: { autoLock.selectedTimeout },
            set: { autoLock.selectedTimeout = $0 }
        )
    }

    private var biometryName: String {
        switch auth.biometryType {
        case .faceID:  return "Face ID"
        case .touchID: return "Touch ID"
        default:       return "Passcode"
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Privacy Policy View

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    Text("Privacy Policy")
                        .font(.title.bold())

                    Text("DocArmor was built with one guiding principle: your data is yours alone.")

                    policySection(
                        title: "No Data Collection",
                        body: "DocArmor collects zero personal data. We have no servers, no accounts, no analytics, and no crash reporting that could expose document content."
                    )

                    policySection(
                        title: "Local Encryption",
                        body: "All documents are encrypted using AES-256-GCM before being written to storage. The encryption key is stored in the iOS Keychain with the 'accessible only when device passcode is set, this device only' protection class — it never leaves your device and is automatically deleted if you remove your device passcode."
                    )

                    policySection(
                        title: "No Network Access",
                        body: "DocArmor makes zero network connections. There are no outbound requests of any kind — no telemetry, no license checks, no updates fetched from the internet."
                    )

                    policySection(
                        title: "Biometric Protection",
                        body: "The app requires Face ID or Touch ID (falling back to your device passcode) every time it is opened or after an idle timeout. The encryption key requires your device passcode to be set — if you remove your passcode, the key is automatically deleted by iOS."
                    )

                    policySection(
                        title: "No iCloud Sync",
                        body: "Documents and the encryption key are explicitly excluded from iCloud backup. Your vault stays on your device only."
                    )

                    policySection(
                        title: "Contact",
                        body: "Questions? Reach us at support@katafract.com"
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func policySection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Document.self, DocumentPage.self], inMemory: true)
        .environment(AuthService())
        .environment(AutoLockService(authService: AuthService()))
}
