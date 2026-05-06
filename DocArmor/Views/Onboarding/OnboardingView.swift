import SwiftUI
import KatafractStyle

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var currentPage = 0

    private struct Page {
        let icon: String
        let title: String
        let body: String
        let color: Color
    }

    private let pages: [Page] = [
        Page(
            icon: "iphone.and.arrow.forward",
            title: "Your Documents Stay Here",
            body: "Everything in DocArmor is encrypted and stored only on this device. No cloud, no account, no server ever sees your documents.",
            color: .kataSapphire
        ),
        Page(
            icon: "key.horizontal.fill",
            title: "Back Up Your Master Key",
            body: "DocArmor uses a unique encryption key tied to your device passcode. If you lose this device without a backup, your documents are gone forever. Export a backup in Settings.",
            color: .kataGold
        ),
        Page(
            icon: "lock.shield.fill",
            title: "Ready to Secure Your Documents",
            body: "Scan, import, or capture your important documents. They'll be encrypted instantly and only accessible with Face ID, Touch ID, or your passcode.",
            color: .kataIce
        ),
    ]

    var body: some View {
        ZStack {
            Color.kataBackgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        pageView(pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Spacer().frame(height: 20)

                Button(action: {
                    if currentPage < pages.count - 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        onComplete()
                    }
                }) {
                    Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(pages[currentPage].color)
                .padding(.horizontal, 32)
                .animation(.easeInOut, value: currentPage)

                if currentPage < pages.count - 1 {
                    Button("Skip") { onComplete() }
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 12)
                }

                Spacer().frame(height: 32)
            }
        }
    }

    private func pageView(_ page: Page) -> some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(page.color.opacity(0.15))
                    .frame(width: 140, height: 140)
                Image(systemName: page.icon)
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(page.color)
            }

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(page.body)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }
}

#Preview {
    OnboardingView {
        print("Onboarding completed")
    }
    .environment(AuthService())
}
