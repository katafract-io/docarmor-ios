import XCTest

class Snapshot: NSObject {

    @objc static func setupSnapshot(_ app: XCUIApplication, delay: Int = 0) {
        setupSnapshot(app, delay: delay, language: nil)
    }

    @objc static func setupSnapshot(_ app: XCUIApplication, delay: Int = 0, language: String?) {
        sleep(UInt32(delay))
    }
}

@objc class SnapshotHelper: NSObject {

    @objc static func snapshot(_ name: String) {
        sleep(1)

        let timestamp = ProcessInfo.processInfo.environment["SNAPSHOT_TIMESTAMP"] ?? ""
        let name = sanitizePathComponent(name)

        if timestamp.isEmpty {
            XCUIApplication().snapshot(name)
        } else {
            XCUIApplication().snapshot("\(timestamp)-\(name)")
        }
    }

    @objc static func snapshot(_ name: String, delay: UInt32) {
        sleep(delay)
        snapshot(name)
    }

    @objc static func setLanguage(_ app: XCUIApplication, _ language: String) {
        let path = NSTemporaryDirectory() + "language.txt"

        do {
            try language.write(toFile: path, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            print("Locale: orderedLanguages not used because we can't write language to file")
        }
    }

    @objc static func setLanguage(_ language: String) {
        let path = NSTemporaryDirectory() + "language.txt"

        do {
            try language.write(toFile: path, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            print("Locale: orderedLanguages not used because we can't write language to file")
        }
    }

    @objc static func deleteLanguageFile() {
        let fileManager = FileManager.default
        let path = NSTemporaryDirectory() + "language.txt"

        do {
            try fileManager.removeItem(atPath: path)
        } catch {
            print("Locale: deleteLanguageFile() could not delete language file")
        }
    }
}

private func sanitizePathComponent(_ string: String) -> String {
    return string.folding(options: .diacriticInsensitive, locale: .current)
        .replacingOccurrences(of: " ", with: "_")
        .replacingOccurrences(of: "/", with: "_")
}
