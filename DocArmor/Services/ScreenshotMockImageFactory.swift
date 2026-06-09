import UIKit

/// Provides mock document page images for screenshot mode.
/// Loads bundled Sasquatch-family document props from the asset catalog
/// (mock_joe_license, mock_auto_insurance, mock_joe_passport, mock_sam_studentid).
/// Falls back to a plain placeholder if an asset is missing so capture never crashes.
enum ScreenshotMockImageFactory {

    static func driverLicenseImage() -> UIImage { bundled("mock_joe_license", w: 1152, h: 768) }
    static func autoInsuranceImage() -> UIImage { bundled("mock_auto_insurance", w: 1152, h: 768) }
    static func passportImage() -> UIImage { bundled("mock_joe_passport", w: 1152, h: 768) }
    static func studentIDImage() -> UIImage { bundled("mock_sam_studentid", w: 1152, h: 768) }

    /// Loads a named asset; if absent, returns a neutral placeholder card of the given size.
    private static func bundled(_ name: String, w: CGFloat, h: CGFloat) -> UIImage {
        if let img = UIImage(named: name) { return img }
        let size = CGSize(width: w, height: h)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor(white: 0.95, alpha: 1).setFill()
            ctx.cgContext.fill(CGRect(origin: .zero, size: size))
        }
    }
}
