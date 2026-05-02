import SwiftUI
import UIKit

/// Hosts a SwiftUI view inside a UIHostingController that locks orientation to
/// landscape and drives the rotation from `viewDidAppear` — *after* SwiftUI has
/// painted its first frame. Fixes the black-on-first-present bug caused by
/// requesting a geometry update before the hosting view has any layer content.
struct LandscapeOnlyContainer<Content: View>: UIViewControllerRepresentable {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIViewController(context: Context) -> LandscapeOnlyHostingController<Content> {
        let vc = LandscapeOnlyHostingController(rootView: content)
        // Use clear background instead of black: when the rotation request
        // races SwiftUI's first paint, an opaque black shows through and
        // the user sees a "black preview" on first tap. Clear lets the
        // transitioning fullScreenCover composite without the black flash.
        vc.view.backgroundColor = .clear
        return vc
    }

    func updateUIViewController(_ vc: LandscapeOnlyHostingController<Content>, context: Context) {
        vc.rootView = content
    }
}

final class LandscapeOnlyHostingController<Content: View>: UIHostingController<Content> {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .landscapeRight }
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }

    private var didRequestRotation = false

    /// Request rotation only after the first real layout pass and only once.
    /// `viewDidAppear` fires during the fullScreenCover's present animation,
    /// which races SwiftUI's first paint — calling requestGeometryUpdate
    /// there shows the user a black frame on first tap (PR #76 deferred via
    /// viewDidAppear but the race window is still open on iOS 17 / 18).
    /// `viewDidLayoutSubviews` runs after the hosting controller has a real
    /// frame to render into, which is the trigger we actually want.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !didRequestRotation, view.bounds.width > 0, view.window != nil else { return }
        didRequestRotation = true
        setNeedsUpdateOfSupportedInterfaceOrientations()
        view.window?.windowScene?
            .requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight)) { _ in }
    }

    /// Explicit empty deinit works around a Swift 6.3.1 EarlyPerfInliner segfault
    /// on the synthesized deinit of this generic UIHostingController subclass.
    /// (Run 25243883558 swift-frontend SIGSEGV on @$s8DocArmor30LandscapeOnlyHostingControllerCfD)
    deinit {}

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.window?.windowScene?
            .requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { _ in }
    }
}
