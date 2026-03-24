import SwiftUI
import UIKit

/// Full-screen document display for showing to airport agents, hotel staff, etc.
/// - Max brightness
/// - Landscape orientation forced
/// - No navigation/tab chrome
/// - Screenshot prevention disabled (user is intentionally showing the doc)
struct PresentModeView: View {
    let images: [UIImage]
    let initialIndex: Int
    let documentName: String

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    @State private var showingDismissConfirm = false
    @State private var previousBrightness: CGFloat = UIScreen.main.brightness

    init(images: [UIImage], initialIndex: Int = 0, documentName: String) {
        self.images = images
        self.initialIndex = initialIndex
        self.documentName = documentName
        _currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(images.indices, id: \.self) { i in
                    Image(uiImage: images[i])
                        .resizable()
                        .scaledToFit()
                        .padding(16)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .always : .never))
            .ignoresSafeArea()

            // Dismiss button (top trailing)
            VStack {
                HStack {
                    Spacer()
                    Button(action: { showingDismissConfirm = true }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(20)
                    }
                }
                Spacer()
            }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            previousBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 1.0
            forceOrientation(.landscapeRight)
        }
        .onDisappear {
            UIScreen.main.brightness = previousBrightness
            forceOrientation(.portrait)
        }
        .confirmationDialog("Exit Present Mode?", isPresented: $showingDismissConfirm, titleVisibility: .visible) {
            Button("Exit Present Mode", role: .destructive) { dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The document will no longer be displayed.")
        }
    }

    // MARK: - Orientation

    private func forceOrientation(_ orientation: UIInterfaceOrientation) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        let mask: UIInterfaceOrientationMask = orientation == .landscapeRight ? .landscapeRight : .portrait
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
    }
}

#Preview {
    PresentModeView(
        images: [UIImage(systemName: "person.crop.rectangle")!],
        documentName: "Driver's License"
    )
}
