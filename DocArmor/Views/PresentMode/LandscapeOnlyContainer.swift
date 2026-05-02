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
        vc.view.backgroundColor = .black
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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
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
