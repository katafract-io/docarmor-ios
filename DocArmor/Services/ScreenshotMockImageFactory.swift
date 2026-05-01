import UIKit

/// Programmatically generates mock document card images for screenshot mode.
/// These images are used to seed DocumentPage data without bundling PNGs.
/// Images are rendered at App Store-ready resolutions.
enum ScreenshotMockImageFactory {
    // MARK: - Driver License Image

    /// Returns a UIImage of a sample driver's license card.
    /// Rendered at 1080x680px (4:2.5 aspect ratio, typical ID card size).
    static func driverLicenseImage() -> UIImage {
        let size = CGSize(width: 1080, height: 680)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            // White background
            UIColor.white.setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: size))

            // Border
            let borderRect = CGRect(origin: .zero, size: size)
            let borderPath = UIBezierPath(
                roundedRect: borderRect,
                byRoundingCorners: .allCorners,
                cornerRadii: CGSize(width: 16, height: 16)
            )
            UIColor.gray.setStroke()
            borderPath.lineWidth = 2
            borderPath.stroke()

            // Vertical divider line (typical DL layout: photo on right, info on left)
            UIColor.lightGray.setStroke()
            let dividerPath = UIBezierPath()
            dividerPath.move(to: CGPoint(x: 360, y: 40))
            dividerPath.addLine(to: CGPoint(x: 360, y: 640))
            dividerPath.lineWidth = 1
            dividerPath.stroke()

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.black
            ]
            let smallAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.darkGray
            ]
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.gray
            ]

            // Header
            "DRIVER LICENSE".draw(at: CGPoint(x: 20, y: 30), withAttributes: attributes)
            "SAMPLE STATE".draw(at: CGPoint(x: 20, y: 60), withAttributes: smallAttributes)

            // Info fields (left column)
            var yPos: CGFloat = 120
            drawField(name: "NAME", value: "SAMPLE DRIVER", at: CGPoint(x: 20, y: yPos), labelAttr: labelAttributes, valueAttr: smallAttributes)
            yPos += 70

            drawField(name: "D.O.B.", value: "01-01-1990", at: CGPoint(x: 20, y: yPos), labelAttr: labelAttributes, valueAttr: smallAttributes)
            yPos += 70

            drawField(name: "LICENSE #", value: "D1234567", at: CGPoint(x: 20, y: yPos), labelAttr: labelAttributes, valueAttr: smallAttributes)
            yPos += 70

            drawField(name: "EXPIRES", value: "01-2030", at: CGPoint(x: 20, y: yPos), labelAttr: labelAttributes, valueAttr: smallAttributes)

            // Photo placeholder (right side, gray rectangle)
            let photoRect = CGRect(x: 380, y: 60, width: 280, height: 350)
            UIColor(white: 0.9, alpha: 1.0).setFill()
            UIBezierPath(rect: photoRect).fill()
            "PHOTO".draw(
                in: CGRect(x: 380, y: 230, width: 280, height: 40),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 14),
                    .foregroundColor: UIColor.gray
                ]
            )

            // Bottom security stripe
            UIColor(white: 0.8, alpha: 1.0).setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 600, width: size.width, height: 80)).fill()
            "SECURITY FEATURES PRESENT".draw(
                at: CGPoint(x: 20, y: 615),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 12),
                    .foregroundColor: UIColor.darkGray
                ]
            )
        }
    }

    // MARK: - Auto Insurance Image

    /// Returns a UIImage of a sample auto insurance card.
    /// Rendered at 1200x780px (typical insurance card size, front side).
    static func autoInsuranceImage() -> UIImage {
        let size = CGSize(width: 1200, height: 780)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            // White background
            UIColor.white.setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: size))

            // Border
            let borderRect = CGRect(origin: .zero, size: size)
            let borderPath = UIBezierPath(
                roundedRect: borderRect,
                byRoundingCorners: .allCorners,
                cornerRadii: CGSize(width: 20, height: 20)
            )
            UIColor.gray.setStroke()
            borderPath.lineWidth = 2
            borderPath.stroke()

            let headerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 28),
                .foregroundColor: UIColor.black
            ]
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 16),
                .foregroundColor: UIColor(red: 0.1, green: 0.1, blue: 0.3, alpha: 1.0)
            ]
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.gray
            ]
            let valueAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: UIColor.black
            ]

            // Company header
            "Acme Mutual".draw(at: CGPoint(x: 40, y: 40), withAttributes: headerAttributes)
            "PROOF OF INSURANCE".draw(at: CGPoint(x: 40, y: 80), withAttributes: titleAttributes)

            // Top divider
            UIColor.lightGray.setStroke()
            let topDivider = UIBezierPath()
            topDivider.move(to: CGPoint(x: 40, y: 130))
            topDivider.addLine(to: CGPoint(x: 1160, y: 130))
            topDivider.lineWidth = 1
            topDivider.stroke()

            // Main content in two columns
            let leftX: CGFloat = 60
            let rightX: CGFloat = 650
            var yPos: CGFloat = 170

            // Left column
            drawField(name: "POLICY #", value: "AC-987654", at: CGPoint(x: leftX, y: yPos), labelAttr: labelAttributes, valueAttr: valueAttributes)
            yPos += 100

            drawField(name: "INSURED NAME", value: "SAMPLE DRIVER", at: CGPoint(x: leftX, y: yPos), labelAttr: labelAttributes, valueAttr: valueAttributes)
            yPos += 100

            drawField(name: "VEHICLE", value: "2021 TESLA MODEL 3", at: CGPoint(x: leftX, y: yPos), labelAttr: labelAttributes, valueAttr: valueAttributes)
            yPos += 100

            // Right column (same height as left)
            var rightYPos: CGFloat = 170

            drawField(name: "EFFECTIVE", value: "06-01-2024", at: CGPoint(x: rightX, y: rightYPos), labelAttr: labelAttributes, valueAttr: valueAttributes)
            rightYPos += 100

            drawField(name: "EXPIRES", value: "06-01-2026", at: CGPoint(x: rightX, y: rightYPos), labelAttr: labelAttributes, valueAttr: valueAttributes)
            rightYPos += 100

            drawField(name: "COVERAGE", value: "100/300/100", at: CGPoint(x: rightX, y: rightYPos), labelAttr: labelAttributes, valueAttr: valueAttributes)

            // Bottom section - Coverage details
            let bottomDivider = UIBezierPath()
            bottomDivider.move(to: CGPoint(x: 40, y: 520))
            bottomDivider.addLine(to: CGPoint(x: 1160, y: 520))
            bottomDivider.lineWidth = 1
            bottomDivider.stroke()

            "COVERAGE INFORMATION".draw(at: CGPoint(x: 60, y: 545), withAttributes: titleAttributes)

            yPos = 590
            drawField(name: "LIABILITY LIMITS", value: "100k / 300k / 100k", at: CGPoint(x: leftX, y: yPos), labelAttr: labelAttributes, valueAttr: valueAttributes)
            yPos += 80

            drawField(name: "DEDUCTIBLE", value: "$500", at: CGPoint(x: leftX, y: yPos), labelAttr: labelAttributes, valueAttr: valueAttributes)

            rightYPos = 590
            drawField(name: "COLLISION", value: "Covered", at: CGPoint(x: rightX, y: rightYPos), labelAttr: labelAttributes, valueAttr: valueAttributes)
            rightYPos += 80

            drawField(name: "COMPREHENSIVE", value: "Covered", at: CGPoint(x: rightX, y: rightYPos), labelAttr: labelAttributes, valueAttr: valueAttributes)
        }
    }

    // MARK: - Helper

    /// Draws a label-value pair, stacked vertically.
    private static func drawField(
        name: String,
        value: String,
        at point: CGPoint,
        labelAttr: [NSAttributedString.Key: Any],
        valueAttr: [NSAttributedString.Key: Any]
    ) {
        name.draw(at: point, withAttributes: labelAttr)
        value.draw(at: CGPoint(x: point.x, y: point.y + 20), withAttributes: valueAttr)
    }
}
