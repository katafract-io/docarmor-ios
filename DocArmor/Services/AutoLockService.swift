import Foundation
import Observation

@Observable
@MainActor
final class AutoLockService {

    enum Timeout: Int, CaseIterable, Identifiable {
        case thirtySeconds = 30
        case oneMinute     = 60
        case fiveMinutes   = 300
        case never         = 0

        var id: Int { rawValue }

        var displayName: String {
            switch self {
            case .thirtySeconds: return "30 Seconds"
            case .oneMinute:     return "1 Minute"
            case .fiveMinutes:   return "5 Minutes"
            case .never:         return "Never"
            }
        }

        var timeInterval: TimeInterval? {
            rawValue == 0 ? nil : TimeInterval(rawValue)
        }
    }

    private static let timeoutKey = "autoLockTimeout"

    var selectedTimeout: Timeout {
        didSet {
            UserDefaults.standard.set(selectedTimeout.rawValue, forKey: Self.timeoutKey)
            // If the user switches from "Never" to any real timeout, start monitoring
            // immediately — don't wait for the next scene-phase transition.
            if oldValue == .never && selectedTimeout != .never {
                startMonitoring()
            } else if selectedTimeout == .never {
                stopMonitoring()
            }
        }
    }

    private var lastActivityTime: Date = .now
    private var monitorTask: Task<Void, Never>?
    private weak var authService: AuthService?

    init(authService: AuthService) {
        let savedValue = UserDefaults.standard.integer(forKey: Self.timeoutKey)
        self.selectedTimeout = Timeout(rawValue: savedValue) ?? .oneMinute
        self.authService = authService
    }

    // MARK: - Activity

    func recordActivity() {
        lastActivityTime = .now
    }

    // MARK: - Monitoring

    func startMonitoring() {
        guard selectedTimeout != .never else { return }
        monitorTask?.cancel()
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                self?.checkIdleTimeout()
            }
        }
    }

    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    private func checkIdleTimeout() {
        guard
            let timeout = selectedTimeout.timeInterval,
            let auth = authService,
            auth.state == .unlocked
        else { return }

        if Date.now.timeIntervalSince(lastActivityTime) >= timeout {
            auth.lock()
        }
    }
}
