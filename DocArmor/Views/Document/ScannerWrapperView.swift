import SwiftUI
import VisionKit

/// Wraps `VNDocumentCameraViewController` for use in SwiftUI.
/// Calls `onCompletion` with an array of scanned `UIImage` pages,
/// `onCancel` when the user dismisses, or `onError` with the underlying error
/// (e.g. camera permission denied) so the caller can show feedback.
struct ScannerWrapperView: UIViewControllerRepresentable {
    let onCompletion: ([UIImage]) -> Void
    let onCancel: () -> Void
    let onError: (Error) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCompletion: onCompletion, onCancel: onCancel, onError: onError)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onCompletion: ([UIImage]) -> Void
        let onCancel: () -> Void
        let onError: (Error) -> Void

        init(onCompletion: @escaping ([UIImage]) -> Void,
             onCancel: @escaping () -> Void,
             onError: @escaping (Error) -> Void) {
            self.onCompletion = onCompletion
            self.onCancel = onCancel
            self.onError = onError
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            var images: [UIImage] = []
            for i in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: i))
            }
            onCompletion(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onCancel()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            // Surface the error rather than silently dismissing.
            // Common cause: camera permission denied — caller shows actionable message.
            onError(error)
        }
    }
}
