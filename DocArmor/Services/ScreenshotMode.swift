import Foundation
import SwiftData
import CryptoKit
import UIKit  // for UIImage in attachMockPage()

/// ScreenshotMode provides seed data for fastlane snapshot captures.
/// Activated via either launch convention:
///   - Legacy: -ScreenshotMode seedData (single-dash, two args — ScreenshotUITestsBase)
///   - Current: --screenshots (double-dash, single arg — ScreenshotTests + ScreenshotLaunchArgs)
public class ScreenshotMode {
    static let isEnabled: Bool = {
        let args = CommandLine.arguments
        let legacy = args.contains("-ScreenshotMode") && args.contains("seedData")
        let current = args.contains("--screenshots")
        return legacy || current
    }()

    static func seedDocuments() -> [Document] {
        let variant = ScreenshotLaunchArgs.seedDataVariant ?? "full-vault"

        // Define documents for three household members with intentional preparedness gaps.
        // This multi-member structure allows frames to show household member assignments
        // and household gaps in preparedness (e.g., "Christian has auto insurance but no vaccine").
        let allDocuments: [Document] = [
            // MARK: - Christian (primary household member)
            // Has: identity (license, passport), auto insurance, health insurance, employee ID
            // Missing: vaccine record, professional license

            Document(
                id: UUID(),
                name: "Driver License - Cascadia",
                ownerName: "Joe Sasquatch",
                documentType: .driversLicense,
                category: .identity,
                notes: "Primary ID, expires in 1 year",
                issuerName: "Cascadia DMV",
                identifierSuffix: "D1234567",
                ocrSuggestedIssuerName: "Cascadia DMV",
                ocrSuggestedIdentifier: "D1234567",
                ocrSuggestedExpirationDate: Date(timeIntervalSinceNow: 365 * 86400),
                ocrConfidenceScore: 0.98,
                ocrExtractedAt: Date(timeIntervalSinceNow: -3600),
                ocrStructureHintsRaw: ["expiration", "number", "name"],
                lastVerifiedAt: Date(timeIntervalSinceNow: -86400),
                renewalNotes: "Renew after 2025",
                expirationDate: Date(timeIntervalSinceNow: 365 * 86400),
                expirationReminderDays: [90, 30],
                isFavorite: true
            ),

            Document(
                id: UUID(),
                name: "Passport - Cascadia",
                ownerName: "Joe Sasquatch",
                documentType: .passport,
                category: .travel,
                notes: "Valid for international travel",
                issuerName: "Cascadia Passport Office",
                identifierSuffix: "C02840293",
                ocrSuggestedIssuerName: "Cascadia Passport Office",
                ocrSuggestedIdentifier: "C02840293",
                ocrSuggestedExpirationDate: Date(timeIntervalSinceNow: 5 * 365 * 86400),
                ocrConfidenceScore: 0.95,
                ocrExtractedAt: Date(timeIntervalSinceNow: -7200),
                ocrStructureHintsRaw: ["passport_number", "expiration", "nationality"],
                lastVerifiedAt: Date(timeIntervalSinceNow: -172800),
                renewalNotes: "Valid until 2029",
                expirationDate: Date(timeIntervalSinceNow: 5 * 365 * 86400),
                expirationReminderDays: [180],
                isFavorite: false
            ),

            Document(
                id: UUID(),
                name: "Auto Insurance - 1989 Bronco",
                ownerName: "Joe Sasquatch",
                documentType: .insuranceAuto,
                category: .financial,
                notes: "Full coverage active",
                issuerName: "Cascadia Mutual",
                identifierSuffix: "AC-987654",
                ocrSuggestedIssuerName: "Cascadia Mutual",
                ocrSuggestedIdentifier: "AC-987654",
                ocrSuggestedExpirationDate: Date(timeIntervalSinceNow: 12 * 86400),
                ocrConfidenceScore: 0.93,
                ocrExtractedAt: Date(timeIntervalSinceNow: -1800),
                ocrStructureHintsRaw: ["policy_number", "expiration", "vehicle"],
                lastVerifiedAt: Date(timeIntervalSinceNow: -604800),
                renewalNotes: "Auto-renew on the 30th — Cascadia Mutual policy AC-987654, $1,247 / 6 mo",
                expirationDate: Date(timeIntervalSinceNow: 12 * 86400), // ~12 days, urgent visual reminder
                expirationReminderDays: [14, 7, 3],
                isFavorite: false
            ),

            Document(
                id: UUID(),
                name: "Health Insurance - Cascadia Health",
                ownerName: "Joe Sasquatch",
                documentType: .insuranceHealth,
                category: .medical,
                notes: "Active employee plan",
                issuerName: "Cascadia Health",
                identifierSuffix: "SHP-8372",
                ocrSuggestedIssuerName: "Cascadia Health",
                ocrSuggestedIdentifier: "SHP-8372",
                ocrSuggestedExpirationDate: Date(timeIntervalSinceNow: 365 * 86400),
                ocrConfidenceScore: 0.96,
                ocrExtractedAt: Date(timeIntervalSinceNow: -5400),
                ocrStructureHintsRaw: ["member_id", "group_number", "effective_date"],
                lastVerifiedAt: Date(timeIntervalSinceNow: -345600),
                renewalNotes: "Renews 2027-01-01",
                expirationDate: Date(timeIntervalSinceNow: 365 * 86400),
                expirationReminderDays: nil,
                isFavorite: false
            ),

            Document(
                id: UUID(),
                name: "Employee ID - Cascadia Forestry",
                ownerName: "Joe Sasquatch",
                documentType: .employeeID,
                category: .work,
                notes: "Valid company badge",
                issuerName: "Cascadia Forestry Co.",
                identifierSuffix: "SC-47829",
                ocrSuggestedIssuerName: "Cascadia Forestry Co.",
                ocrSuggestedIdentifier: "SC-47829",
                ocrSuggestedExpirationDate: nil,
                ocrConfidenceScore: 0.97,
                ocrExtractedAt: Date(timeIntervalSinceNow: -9000),
                ocrStructureHintsRaw: ["employee_number", "department"],
                lastVerifiedAt: Date(timeIntervalSinceNow: -172800),
                renewalNotes: "No expiration",
                expirationDate: nil,
                expirationReminderDays: nil,
                isFavorite: false
            ),

            // MARK: - Jane (household member)
            // Has: identity (license), vaccine record, health insurance
            // Missing: passport, auto insurance (preparedness gap)

            Document(
                id: UUID(),
                name: "Driver License - Cascadia",
                ownerName: "Jane Sasquatch",
                documentType: .driversLicense,
                category: .identity,
                notes: "Valid CA license",
                issuerName: "Cascadia DMV",
                identifierSuffix: "D9876543",
                ocrSuggestedIssuerName: "Cascadia DMV",
                ocrSuggestedIdentifier: "D9876543",
                ocrSuggestedExpirationDate: Date(timeIntervalSinceNow: 2 * 365 * 86400),
                ocrConfidenceScore: 0.97,
                ocrExtractedAt: Date(timeIntervalSinceNow: -5400),
                ocrStructureHintsRaw: ["expiration", "number", "name"],
                lastVerifiedAt: Date(timeIntervalSinceNow: -259200),
                renewalNotes: "Expires 2028-04-15",
                expirationDate: Date(timeIntervalSinceNow: 2 * 365 * 86400),
                expirationReminderDays: [180, 90],
                isFavorite: false
            ),

            Document(
                id: UUID(),
                name: "Vaccine Record - COVID-19",
                ownerName: "Jane Sasquatch",
                documentType: .vaccineRecord,
                category: .medical,
                notes: "Booster completed 2024",
                issuerName: "Cascadia Health Dept.",
                identifierSuffix: "VACC-Jane-2024",
                ocrSuggestedIssuerName: "Cascadia Health Dept.",
                ocrSuggestedIdentifier: "VACC-Jane-2024",
                ocrSuggestedExpirationDate: nil,
                ocrConfidenceScore: 0.91,
                ocrExtractedAt: Date(timeIntervalSinceNow: -10800),
                ocrStructureHintsRaw: ["vaccine_type", "date_administered"],
                lastVerifiedAt: Date(timeIntervalSinceNow: -86400),
                renewalNotes: "Booster may expire per CDC guidance",
                expirationDate: nil,
                expirationReminderDays: nil,
                isFavorite: false
            ),

            Document(
                id: UUID(),
                name: "Health Insurance - Cascadia Health",
                ownerName: "Jane Sasquatch",
                documentType: .insuranceHealth,
                category: .medical,
                notes: "Dependent on family plan",
                issuerName: "Cascadia Health",
                identifierSuffix: "SHP-8372-D1",
                ocrSuggestedIssuerName: "Cascadia Health",
                ocrSuggestedIdentifier: "SHP-8372-D1",
                ocrSuggestedExpirationDate: Date(timeIntervalSinceNow: 365 * 86400),
                ocrConfidenceScore: 0.96,
                ocrExtractedAt: Date(timeIntervalSinceNow: -7200),
                ocrStructureHintsRaw: ["member_id", "group_number"],
                lastVerifiedAt: Date(timeIntervalSinceNow: -432000),
                renewalNotes: "Covered until 2027-01-01",
                expirationDate: Date(timeIntervalSinceNow: 365 * 86400),
                expirationReminderDays: nil,
                isFavorite: false
            ),

            // MARK: - Sam (child household member)
            // Has: school student ID, vaccine record (up to date)

            Document(
                id: UUID(),
                name: "Student ID - Cascadia Elementary",
                ownerName: "Sam Sasquatch",
                documentType: .custom,
                category: .identity,
                notes: "Grade 3 student ID card",
                issuerName: "Cascadia Elementary",
                identifierSuffix: "CE-2031",
                ocrSuggestedIssuerName: "Cascadia Elementary",
                ocrSuggestedIdentifier: "CE-2031",
                ocrConfidenceScore: 0.90,
                ocrExtractedAt: Date(timeIntervalSinceNow: -6000),
                ocrStructureHintsRaw: ["student_number", "grade"],
                lastVerifiedAt: Date(timeIntervalSinceNow: -172800),
                renewalNotes: "Reissued each school year",
                expirationDate: nil,
                expirationReminderDays: nil,
                isFavorite: false
            ),

            Document(
                id: UUID(),
                name: "Vaccine Record - Cascadia Elementary",
                ownerName: "Sam Sasquatch",
                documentType: .vaccineRecord,
                category: .medical,
                notes: "School immunizations up to date",
                issuerName: "Cascadia Health Dept.",
                identifierSuffix: "VACC-Sam-2025",
                ocrSuggestedIssuerName: "Cascadia Health Dept.",
                ocrSuggestedIdentifier: "VACC-Sam-2025",
                ocrSuggestedExpirationDate: nil,
                ocrConfidenceScore: 0.91,
                ocrExtractedAt: Date(timeIntervalSinceNow: -9000),
                ocrStructureHintsRaw: ["vaccine_type", "date_administered"],
                lastVerifiedAt: Date(timeIntervalSinceNow: -86400),
                renewalNotes: "Next dose per school schedule",
                expirationDate: nil,
                expirationReminderDays: nil,
                isFavorite: false
            ),

            // MARK: - Shared (household vault, nil ownerName)
            // Documents owned by no single person but needed for household preparedness

            Document(
                id: UUID(),
                name: "Professional License - Real Estate Agent",
                ownerName: nil,
                documentType: .professionalLicense,
                category: .work,
                notes: "Active real estate broker license",
                issuerName: "Cascadia Real Estate Board",
                identifierSuffix: "REB-47382",
                ocrSuggestedIssuerName: "Cascadia Real Estate Board",
                ocrSuggestedIdentifier: "REB-47382",
                ocrSuggestedExpirationDate: Date(timeIntervalSinceNow: 180 * 86400),
                ocrConfidenceScore: 0.92,
                ocrExtractedAt: Date(timeIntervalSinceNow: -14400),
                ocrStructureHintsRaw: ["license_number", "expiration"],
                lastVerifiedAt: Date(timeIntervalSinceNow: -604800),
                renewalNotes: "Renew before 2026-12-15",
                expirationDate: Date(timeIntervalSinceNow: 180 * 86400),
                expirationReminderDays: [60, 30],
                isFavorite: false
            ),

            Document(
                id: UUID(),
                name: "Mortgage Statement - Primary Residence",
                ownerName: nil,
                documentType: .custom,
                category: .financial,
                notes: "Current loan balance and payment details",
                issuerName: "Pine Hollow Savings",
                identifierSuffix: "Loan-3728",
                ocrSuggestedIssuerName: "Pine Hollow Savings",
                ocrSuggestedIdentifier: "Loan-3728",
                ocrSuggestedExpirationDate: Date(timeIntervalSinceNow: 30 * 365 * 86400),
                ocrConfidenceScore: 0.94,
                ocrExtractedAt: Date(timeIntervalSinceNow: -18000),
                ocrStructureHintsRaw: ["balance", "payment_amount", "rate"],
                lastVerifiedAt: Date(timeIntervalSinceNow: -345600),
                renewalNotes: "30-year fixed at 3.875%, matures 2054",
                expirationDate: Date(timeIntervalSinceNow: 30 * 365 * 86400),
                expirationReminderDays: nil,
                isFavorite: false
            ),

            Document(
                id: UUID(),
                name: "Vehicle Title - 1989 Bronco",
                ownerName: nil,
                documentType: .custom,
                category: .custom,
                notes: "Clear title on file, owned outright",
                issuerName: "Cascadia DMV",
                identifierSuffix: "Title-4KL9Z3TQ",
                ocrSuggestedIssuerName: "Cascadia DMV",
                ocrSuggestedIdentifier: "4KL9Z3TQ",
                ocrConfidenceScore: 0.90,
                ocrExtractedAt: Date(timeIntervalSinceNow: -21600),
                ocrStructureHintsRaw: ["vin", "odometer", "owner_name"],
                lastVerifiedAt: Date(timeIntervalSinceNow: -432000),
                renewalNotes: "Owned free and clear since 2023",
                expirationDate: nil,
                expirationReminderDays: nil,
                isFavorite: false
            ),

            Document(
                id: UUID(),
                name: "Tax Return 2024",
                ownerName: nil,
                documentType: .custom,
                category: .financial,
                notes: "Filed with IRS, joint return",
                issuerName: "Internal Revenue Service",
                identifierSuffix: "2024-Return",
                ocrSuggestedIssuerName: "Internal Revenue Service",
                ocrSuggestedIdentifier: "1040-2024",
                ocrSuggestedExpirationDate: Date(timeIntervalSinceNow: 7 * 365 * 86400),
                ocrConfidenceScore: 0.93,
                ocrExtractedAt: Date(timeIntervalSinceNow: -25200),
                ocrStructureHintsRaw: ["filing_date", "tax_year"],
                lastVerifiedAt: Date(timeIntervalSinceNow: -259200),
                renewalNotes: "Retain copies for 7 years per IRS guidance",
                expirationDate: nil,
                expirationReminderDays: nil,
                isFavorite: false
            ),

            Document(
                id: UUID(),
                name: "Home Insurance - Homeowners",
                ownerName: nil,
                documentType: .insuranceHome,
                category: .financial,
                notes: "Full replacement value coverage",
                issuerName: "Cascadia Mutual",
                identifierSuffix: "HO-392857",
                ocrSuggestedIssuerName: "Cascadia Mutual",
                ocrSuggestedIdentifier: "HO-392857",
                ocrSuggestedExpirationDate: Date(timeIntervalSinceNow: 365 * 86400),
                ocrConfidenceScore: 0.94,
                ocrExtractedAt: Date(timeIntervalSinceNow: -28800),
                ocrStructureHintsRaw: ["policy_number", "expiration", "coverage_limit"],
                lastVerifiedAt: Date(timeIntervalSinceNow: -172800),
                renewalNotes: "Renews 2026-08-01",
                expirationDate: Date(timeIntervalSinceNow: 365 * 86400),
                expirationReminderDays: [60],
                isFavorite: false
            )
        ]

        // Branch on variant for different screenshot scenarios
        let result: [Document] = switch variant {
        case "minimal":
            // Return only first 3 documents for minimal vault display
            Array(allDocuments.prefix(3))
        case "preparedness", "full-vault":
            // Return all documents (3-member Sasquatch household); "preparedness" needs the gaps to show
            allDocuments
        default:
            allDocuments
        }

        // --auto-open selects the first match in createdAt-desc order. Bump Joe's
        // licence + auto-insurance to a fresh timestamp so the auto-opened document
        // is always the one that has a mock page image attached (not Jane's ID).
        for document in result where document.ownerName == "Joe Sasquatch"
            && (document.documentType == .driversLicense || document.documentType == .insuranceAuto) {
            document.createdAt = Date.now
        }

        // Populate encrypted pages for documents that need preview rendering
        // (driversLicense + insuranceAuto for Frames 3-4)
        for document in result where document.pages.isEmpty {
            switch (document.ownerName ?? "", document.documentType) {
            case ("Joe Sasquatch", .driversLicense):
                attachMockPage(to: document, image: ScreenshotMockImageFactory.driverLicenseImage())
            case ("Joe Sasquatch", .insuranceAuto):
                attachMockPage(to: document, image: ScreenshotMockImageFactory.autoInsuranceImage())
            case ("Joe Sasquatch", .passport):
                attachMockPage(to: document, image: ScreenshotMockImageFactory.passportImage())
            case ("Sam Sasquatch", .custom) where document.name.contains("Student ID"):
                attachMockPage(to: document, image: ScreenshotMockImageFactory.studentIDImage())
            default:
                break
            }
        }

        return result
    }

    static func makeSovereignEntitlementOverride() -> Bool {
        true
    }

    /// Attach an encrypted mock page to a document for screenshot rendering.
    /// Generates a vault key if needed, encrypts the image, and creates a DocumentPage.
    /// Screenshot-mode only — errors are logged but don't block document display.
    private static func attachMockPage(to document: Document, image: UIImage) {
        do {
            // For screenshot mode, always use a mock key (not stored in keychain)
            // This allows frames to decrypt and display the mock images.
            let mockKeyData = Data(repeating: 0x42, count: 32)  // AES-256 = 32 bytes
            let mockKey = SymmetricKey(data: mockKeyData)

            guard let imageData = image.jpegData(compressionQuality: 0.85) else {
                return
            }

            let nonce = AES.GCM.Nonce()
            let sealedBox = try AES.GCM.seal(imageData, using: mockKey, nonce: nonce)

            let encryptedData = sealedBox.ciphertext + sealedBox.tag
            let page = DocumentPage(
                id: UUID(),
                pageIndex: 0,
                encryptedImageData: encryptedData,
                nonce: Data(nonce),
                label: nil
            )
            document.pages.append(page)
        } catch {
            // Silent fail for screenshots — the document will render without preview
            return
        }
    }
}
