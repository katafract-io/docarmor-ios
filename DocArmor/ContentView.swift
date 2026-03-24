import SwiftUI

/// Root auth-gate router. Switches between the lock screen and the main vault
/// based on `AuthService.state`. Also wires auto-lock activity tracking.
struct ContentView: View {
    @Environment(AuthService.self) private var auth
    @Environment(AutoLockService.self) private var autoLock

    var body: some View {
        Group {
            switch auth.state {
            case .locked, .authenticating:
                LockScreenView()
                    .transition(.opacity)
            case .unlocked:
                HomeView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: auth.state == .unlocked)
        // Track user taps anywhere in the unlocked app for auto-lock idle timer
        .simultaneousGesture(
            TapGesture().onEnded { autoLock.recordActivity() },
            including: .all
        )
    }
}

#Preview {
    ContentView()
        .environment(AuthService())
        .environment(AutoLockService(authService: AuthService()))
}
