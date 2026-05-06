import SwiftUI
import SwiftData
import KatafractStyle

@main
struct DocArmorApp: App {
    @Environment(\.scenePhase) private var scenePhase

    // Both services share the same AuthService instance so AutoLock can call lock().
    // They are initialised once in init() and stored as @State to survive re-renders.
    @State private var authService: AuthService
    @State private var autoLockService: AutoLockService
    @State private var entitlementService: EntitlementService

    // Deep-link state for Siri / widget → open a specific document type or category
    @State private var pendingDocumentType: DocumentType?
    @State private var pendingCategory: DocumentCategory?

    // Key loss detection: set when VaultKey is absent on launch but documents exist
    @AppStorage("docarmor.keyLostWithDocuments") private var keyLostWithDocuments = false

    // Backup nag: shown once every 7 days when user has 3+ documents and never exported
    @AppStorage("docarmor.hasExportedBackup") private var hasExportedBackup = false
    @AppStorage("docarmor.backupNagShownDate") private var backupNagShownDate = 0.0
    @State private var showBackupNag = false

    private let modelContainer: ModelContainer

    init() {
        // Configure SwiftData with explicit no-CloudKit to ensure local-only storage
        let config = ModelConfiguration(
            schema: Schema([Document.self, DocumentPage.self]),
            isStoredInMemoryOnly: ScreenshotMode.isEnabled, // Use in-memory DB for screenshot tests
            allowsSave: true,
            cloudKitDatabase: .none
        )
        do {
            modelContainer = try ModelContainer(for: Document.self, DocumentPage.self, configurations: config)
            // Seed synthetic documents when ScreenshotMode is active
            #if DEBUG
            modelContainer.seedScreenshotModeData()
            #endif
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }

        // Apply screenshot-mode launch argument overrides
        if ScreenshotLaunchArgs.skipOnboarding {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }

        // Provision vault key on first launch.
        // `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` requires the device
        // to have a passcode. If it doesn't, generate() throws and we surface a
        // flag so the UI can explain the situation instead of failing silently later.
        if !VaultKey.exists {
            // Check if user already has documents encrypted with the (now lost) key.
            // This happens when the device passcode changes, revoking WhenPasscodeSetThisDeviceOnly keys.
            let tempContext = ModelContext(modelContainer)
            let docCount = (try? tempContext.fetchCount(FetchDescriptor<Document>())) ?? 0
            if docCount > 0 {
                // Key was revoked (passcode change) but encrypted documents exist.
                // New key will be generated but old docs are permanently unreadable.
                UserDefaults.standard.set(true, forKey: "docarmor.keyLostWithDocuments")
            }
            do {
                try VaultKey.generate()
            } catch {
                // VaultKey.noPasscode is checked by LockScreenView to show
                // an actionable "Set a device passcode to use DocArmor" message.
                UserDefaults.standard.set(true, forKey: "vaultKeyProvisioningFailed")
            }
        }

        // Create a single AuthService and hand the same reference to AutoLockService.
        // Using _property = State(initialValue:) is the correct pattern for initialising
        // @State inside init() without creating a discarded duplicate instance.
        let auth = AuthService()
        _authService    = State(initialValue: auth)
        _autoLockService = State(initialValue: AutoLockService(authService: auth))

        // Initialize EntitlementService for StoreKit 2 monetization
        _entitlementService = State(initialValue: EntitlementService())

        excludeVaultFromBackup()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authService)
                .environment(autoLockService)
                .environment(entitlementService)
                .environment(\.pendingDocumentType, $pendingDocumentType)
                .environment(\.pendingCategory, $pendingCategory)
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .background:
                        authService.lock()
                        autoLockService.stopMonitoring()
                    case .active:
                        autoLockService.startMonitoring()
                        // Trigger auth only on .active to avoid LAError.notInteractive
                        if authService.state == .locked {
                            Task { await authService.authenticate() }
                        }
                        // Retry any unsynced documents in background
                        Task.detached(priority: .background) {
                            await retrySovereignBackups(modelContainer: modelContainer)
                        }
                    default:
                        break
                    }
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .onReceive(NotificationCenter.default.publisher(for: .showDocumentIntent)) { notification in
                    guard
                        let typeValue = notification.userInfo?["documentType"] as? String,
                        let docType = DocumentType(rawValue: typeValue)
                    else { return }
                    pendingDocumentType = docType
                }
                .onReceive(NotificationCenter.default.publisher(for: .openCategoryIntent)) { notification in
                    guard
                        let categoryValue = notification.userInfo?["category"] as? String,
                        let category = DocumentCategory(rawValue: categoryValue)
                    else { return }
                    pendingCategory = category
                }
                .task {
                    entitlementService.startListening()
                    // Check backup nag: show once if user has documents and never exported
                    if !hasExportedBackup {
                        let daysSinceNag = (Date.now.timeIntervalSince1970 - backupNagShownDate) / 86400
                        if daysSinceNag > 7 {
                            let ctx = modelContainer.mainContext
                            let count = (try? ctx.fetchCount(FetchDescriptor<Document>())) ?? 0
                            if count >= 3 {
                                showBackupNag = true
                                backupNagShownDate = Date.now.timeIntervalSince1970
                            }
                        }
                    }
                }
                .onAppear {
                    wireAutoOpenIfNeeded()
                }
                .alert("Encryption Key Lost", isPresented: $keyLostWithDocuments) {
                    Button("Reset Vault", role: .destructive) {
                        // Delete all documents and clear the flag
                        Task { @MainActor in
                            do {
                                let ctx = modelContainer.mainContext
                                let docs = try ctx.fetch(FetchDescriptor<Document>())
                                for doc in docs { ctx.delete(doc) }
                                try ctx.save()
                            } catch { }
                            UserDefaults.standard.removeObject(forKey: "docarmor.keyLostWithDocuments")
                            keyLostWithDocuments = false
                        }
                    }
                    Button("Cancel", role: .cancel) {
                        // User acknowledges but keeps (unreadable) documents for now
                        keyLostWithDocuments = false
                    }
                } message: {
                    Text("Your device passcode changed and the encryption key was revoked. Your existing documents can no longer be decrypted. Reset the vault to start fresh, or cancel to keep the encrypted files (they cannot be read).")
                }
                .alert("Back Up Your Vault", isPresented: $showBackupNag) {
                    Button("Go to Settings") {
                        // Navigate to settings/backup section
                        pendingDocumentType = nil
                        // Set a flag to navigate in ContentView if needed
                    }
                    Button("Not now", role: .cancel) { }
                } message: {
                    Text("You have 3+ documents. Regular backups protect against unexpected data loss. Export a backup to your Files app.")
                }
                .tint(KataAccent.gold)
        }
        .modelContainer(modelContainer)
    }

    // MARK: - Deep Link

    /// Wires the --auto-open <documentType> launch argument to navigate to a document.
    /// Dispatches via the existing pendingDocumentType path after a brief delay to allow
    /// navigation hierarchy to be ready.
    private func wireAutoOpenIfNeeded() {
        guard let typeStr = ScreenshotLaunchArgs.autoOpenDocumentType else { return }

        // Accept either the human raw value ("Auto Insurance") OR the case name
        // ("insuranceAuto") — UI tests pass case names, deep links pass raw values.
        let docType = DocumentType(rawValue: typeStr)
            ?? DocumentType.allCases.first(where: { String(describing: $0) == typeStr })
        guard let docType else { return }

        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            pendingDocumentType = docType
        }
    }

    /// Handles `docarmor://open?type=driversLicense` URLs from widgets and Siri.
    private func handleDeepLink(_ url: URL) {
        guard
            url.scheme == "docarmor",
            url.host == "open",
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let typeValue = components.queryItems?.first(where: { $0.name == "type" })?.value,
            let docType = DocumentType(rawValue: typeValue)
        else { return }
        pendingDocumentType = docType
    }

    private func excludeVaultFromBackup() {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }

        for filename in ["default.store", "default.store-wal", "default.store-shm"] {
            var url = appSupport.appendingPathComponent(filename)
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try? url.setResourceValues(resourceValues)
        }
    }

    /// Retry backup for all documents with lastBackedUpAt == nil (never backed up).
    /// Called on scene .active when user has Sovereign/Founder plan and backup is enabled.
    private nonisolated func retrySovereignBackups(modelContainer: ModelContainer) async {
        guard SovereignBackupService.sovereignToken() != nil else { return }
        guard UserDefaults.standard.object(forKey: "sovereignBackup.enabled") as? Bool ?? true else { return }

        let key: SymmetricKey
        do {
            key = try VaultKey.load()
        } catch {
            return
        }

        let ctx = ModelContext(modelContainer)
        let unsynced: [Document]
        do {
            unsynced = try ctx.fetch(FetchDescriptor<Document>(
                predicate: #Predicate { $0.lastBackedUpAt == nil }
            ))
        } catch {
            return
        }

        for doc in unsynced {
            let success = await SovereignBackupService.backup(document: doc, vaultKey: key)
            if success {
                await MainActor.run {
                    doc.lastBackedUpAt = Date.now
                    try? ctx.save()
                }
            }
        }
    }
}

// MARK: - Environment Keys for deep-link state

private struct PendingDocumentTypeKey: EnvironmentKey {
    static let defaultValue: Binding<DocumentType?> = .constant(nil)
}

private struct PendingCategoryKey: EnvironmentKey {
    static let defaultValue: Binding<DocumentCategory?> = .constant(nil)
}

extension EnvironmentValues {
    var pendingDocumentType: Binding<DocumentType?> {
        get { self[PendingDocumentTypeKey.self] }
        set { self[PendingDocumentTypeKey.self] = newValue }
    }

    var pendingCategory: Binding<DocumentCategory?> {
        get { self[PendingCategoryKey.self] }
        set { self[PendingCategoryKey.self] = newValue }
    }
}
