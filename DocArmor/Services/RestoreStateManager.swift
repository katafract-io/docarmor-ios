import Foundation

/// Tracks encrypted backup restore progress across app launches.
/// Used for recovery if the app terminates during an incomplete restore.
/// Each restore session has a unique stage identifier that persists until cleared.
enum RestoreStateManager {
    enum RestoreStage: String, Codable {
        /// Restore begun; payload validated and decoded
        case initialized = "restore.initialized"
        /// Vault key installation in progress
        case keyInstallation = "restore.key_installation"
        /// Vault key installed; documents about to be replaced
        case modelReplacement = "restore.model_replacement"
        /// Documents replaced; reminders about to be scheduled
        case reminderScheduling = "restore.reminder_scheduling"
        /// Full restore complete
        case completed = "restore.completed"
    }

    struct RestoreJournal: Codable {
        let sessionID: UUID
        let startedAt: Date
        var currentStage: RestoreStage
        var backupPayload: BackupService.BackupPayload?
        var householdMembers: [String] = []
        var insertedDocumentIDs: [UUID] = []
    }

    private static let userDefaultsKey = "docarmor.restoreJournal"
    private static let payloadKey = "docarmor.restorePayload"

    /// Begins a new restore session, returning a journal to track progress.
    static func beginRestore() -> RestoreJournal {
        let journal = RestoreJournal(
            sessionID: UUID(),
            startedAt: .now,
            currentStage: .initialized
        )
        saveJournal(journal)
        return journal
    }

    /// Loads any in-progress restore journal.
    static func loadJournal() -> RestoreJournal? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return nil }
        return try? JSONDecoder().decode(RestoreJournal.self, from: data)
    }

    /// Updates the journal stage and persists it.
    static func updateStage(_ stage: RestoreStage, journal: inout RestoreJournal) {
        journal.currentStage = stage
        saveJournal(journal)
    }

    /// Marks restore as completed and clears the journal.
    static func completeRestore() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: payloadKey)
    }

    /// Discards the journal without marking completion (for recovery failures).
    static func discardJournal() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: payloadKey)
    }

    /// Stores the backup payload for recovery if the app terminates mid-restore.
    static func storePayload(_ payload: BackupService.BackupPayload) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: payloadKey)
    }

    /// Retrieves the stored backup payload.
    static func loadPayload() -> BackupService.BackupPayload? {
        guard let data = UserDefaults.standard.data(forKey: payloadKey) else { return nil }
        return try? JSONDecoder().decode(BackupService.BackupPayload.self, from: data)
    }

    private static func saveJournal(_ journal: RestoreJournal) {
        guard let data = try? JSONEncoder().encode(journal) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }
}
