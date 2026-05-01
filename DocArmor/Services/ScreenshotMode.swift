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
                name: "Driver License - California",
                ownerName: "Christian",
                documentType: .driversLicense,
                category: .identity,
                notes: "Primary ID, expires in 1 year",
                issuerName: "Sample State DMV",
                identifierSuffix: "D1234567",
                ocrSuggestedIssuerName: "Sample State DMV",
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
                name: "Passport - United States",
                ownerName: "Christian",
                documentType: .passport,
                category: .travel,
                notes: "Valid for international travel",
                issuerName: "U.S. Department of State",
                identifierSuffix: "C02840293",
                ocrSuggestedIssuerName: "U.S. Department of State",
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
                name: "Auto Insurance - 2021 Tesla Model 3",
                ownerName: "Christian",
                documentType: .insuranceAuto,
                category: .financial,
                notes: "Full coverage active",
                issuerName: "Acme Mutual",
                identifierSuffix: "AC-987654",
                ocrSuggestedIssuerName: "Acme Mutual",
                ocrSuggestedIdentifier: "AC-987654",
                ocrSuggestedExpirationDate: Date(timeIntervalSinceNow: 12 * 86400),
                ocrConfidenceScore: 0.93,
                ocrExtractedAt: Date(timeIntervalSinceNow: -1800),
                ocrStructureHintsRaw: ["policy_number", "expiration", "vehicle"],
                lastVerifiedAt: Date(timeIntervalSinceNow: -604800),
                renewalNotes: "Auto-renew on the 30th — Acme Mutual policy AC-987654, $1,247 / 6 mo",
                expirationDate: Date(timeIntervalSinceNow: 12 * 86400), // ~12 days, urgent visual reminder
                expirationReminderDays: [14, 7, 3],
                isFavorite: false
            ),

            Document(
                id: UUID(),
                name: "Health Insurance - Sample Health Plan",
                ownerName: "Christian",
                documentType: .insuranceHealth,
                category: .medical,
                notes: "Active employee plan",
                issuerName: "Sample Health Plan",
                identifierSuffix: "SHP-8372",
                ocrSuggestedIssuerName: "Sample Health Plan",
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
                name: "Employee ID - SampleCorp",
                ownerName: "Christian",
                documentType: .employeeID,
                category: .work,
                notes: "Valid company badge",
                issuerName: "SampleCorp Inc.",
                identifierSuffix: "SC-47829",
                ocrSuggestedIssuerName: "SampleCorp Inc.",
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
                name: "Driver License - California",
                ownerName: "Jane",
                documentType: .driversLicense,
                category: .identity,
                notes: "Valid CA license",
                issuerName: "Sample State DMV",
                identifierSuffix: "D9876543",
                ocrSuggestedIssuerName: "Sample State DMV",
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
                ownerName: "Jane",
                documentType: .vaccineRecord,
                category: .medical,
                notes: "Booster completed 2024",
                issuerName: "Sample Health Dept.",
                identifierSuffix: "VACC-Jane-2024",
                ocrSuggestedIssuerName: "Sample Health Dept.",
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
                name: "Health Insurance - Sample Health Plan",
                ownerName: "Jane",
                documentType: .insuranceHealth,
                category: .medical,
                notes: "Dependent on family plan",
                issuerName: "Sample Health Plan",
                identifierSuffix: "SHP-8372-D1",
                ocrSuggestedIssuerName: "Sample Health Plan",
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

            // MARK: - Shared (household vault, nil ownerName)
            // Documents owned by no single person but needed for household preparedness

            Document(
                id: UUID(),
                name: "Professional License - Real Estate Agent",
                ownerName: nil,
                documentType: .professionalLicense,
                category: .work,
                notes: "Active real estate broker license",
                issuerName: "Sample State Real Estate Board",
                identifierSuffix: "REB-47382",
                ocrSuggestedIssuerName: "Sample State Real Estate Board",
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
                issuerName: "First National Bank",
                identifierSuffix: "Loan-3728",
                ocrSuggestedIssuerName: "First National Bank",
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
                name: "Vehicle Title - 2021 Tesla Model 3",
                ownerName: nil,
                documentType: .custom,
                category: .custom,
                notes: "Clear title on file, owned outright",
                issuerName: "Sample State DMV",
                identifierSuffix: "Title-4KL9Z3TQ",
                ocrSuggestedIssuerName: "Sample State DMV",
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
                issuerName: "Acme Mutual",
                identifierSuffix: "HO-392857",
                ocrSuggestedIssuerName: "Acme Mutual",
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
            // Return all 14 documents; "preparedness" needs the gaps to show
            allDocuments
        default:
            allDocuments
        }

        // Populate encrypted pages for documents that need preview rendering
        // (driversLicense + insuranceAuto for Frames 3-4)
        for document in result {
            if document.documentType == .driversLicense && document.pages.isEmpty {
                attachMockPage(to: document, image: ScreenshotMockImageFactory.driverLicenseImage())
            } else if document.documentType == .insuranceAuto && document.pages.isEmpty {
                attachMockPage(to: document, image: ScreenshotMockImageFactory.autoInsuranceImage())
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
