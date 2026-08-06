import XCTest

/// Test to prevent false privacy claims from being reintroduced.
/// Issue #146: Ensures that claims like "zero network", "only on this device", etc.
/// are not present in copy/docs while Vaultyx cloud backup code exists.
final class PrivacyClaimsTest: XCTestCase {

    /// List of banned absolute claims that contradict actual cloud backup behavior
    private let bannedPhrases = [
        "zero network",
        "no network calls",
        "never leaves this device",
        "only on this device",
        "only on the device",
        "image pages stay on-device",
        "metadata only",
    ]

    /// Files to scan for banned phrases
    private let filesToCheck: [(path: String, context: String)] = [
        ("SECURITY.md", "SECURITY.md"),
        ("README.md", "README.md"),
        ("fastlane/metadata/en-US/description.txt", "App Store description"),
    ]

    func testPrivacyClaimsAreAccurate() throws {
        var violations = [(file: String, phrase: String, line: Int)]()

        for fileInfo in filesToCheck {
            guard let fileURL = fileURL(for: fileInfo.path) else {
                XCTFail("Could not find file: \(fileInfo.path)")
                continue
            }

            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)

            for (lineNum, line) in lines.enumerated() {
                let lowerLine = line.lowercased()
                for phrase in bannedPhrases {
                    if lowerLine.contains(phrase) {
                        violations.append((file: fileInfo.context, phrase: phrase, line: lineNum + 1))
                    }
                }
            }
        }

        if !violations.isEmpty {
            let summary = violations
                .map { "\(​$0.file) line \($0.line): contains '\($0.phrase)'" }
                .joined(separator: "\n")
            XCTFail(
                """
                Found banned privacy claims (Issue #146). \
                These phrases contradict actual cloud backup behavior:
                \n\(summary)
                """
            )
        }
    }

    /// Find a file relative to the project root
    private func fileURL(for relativePath: String) -> URL? {
        // Start from the test bundle and navigate up to project root
        let bundle = Bundle(for: type(of: self))
        guard let bundlePath = bundle.bundlePath as String? else { return nil }

        let components = bundlePath.components(separatedBy: "/")
        // Navigate from .../Build/Products/Debug-iphonesimulator/DocArmorUITests.xctest
        // to the project root
        var projectPath = components.dropLast(5).joined(separator: "/")
        if projectPath.isEmpty { projectPath = "/tmp/audit-fix-docarmor-146" } // Fallback

        let fileURL = URL(fileURLWithPath: projectPath)
            .appendingPathComponent(relativePath)

        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }
}
