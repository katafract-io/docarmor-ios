import SwiftUI
import StoreKit

enum PaywallReason {
    case presentMode, travelMode, smartPacks, household, familyVault

    var title: String {
        "Upgrade DocArmor"
    }

    var subtitle: String {
        switch self {
        case .presentMode:
            "Present Mode gives you full brightness and landscape view to show documents to airport agents, hotel staff, and more."
        case .travelMode:
            "Travel Mode is a Pro feature — keep all your travel documents ready in one tap."
        case .smartPacks:
            "Smart Packs organize documents by life event. Create unlimited packs with Pro."
        case .household:
            "Manage household members and organize documents per person with Pro."
        case .familyVault:
            "Family Vault lets you securely share documents and manage household access across family devices."
        }
    }
}

struct PaywallView: View {
    let reason: PaywallReason
    let entitlementService: EntitlementService
    let dismiss: () -> Void

    @State private var purchaseError: String?
    @State private var showingError = false
    @State private var selectedProductID: String?
    @State private var proMonthlyProduct: Product?
    @State private var proAnnualProduct: Product?
    @State private var familyMonthlyProduct: Product?
    @State private var familyAnnualProduct: Product?
    @State private var showProAnnual = false
    @State private var showFamilyAnnual = false

    var body: some View {
        ZStack {
            Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.08, green: 0.07, blue: 0.12, alpha: 1) : UIColor(red: 0.97, green: 0.96, blue: 0.99, alpha: 1) })
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: Header
                VStack(spacing: 16) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)

                    VStack(spacing: 8) {
                        Text(reason.title)
                            .font(.title2.bold())
                        Text(reason.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(4)
                    }
                    .multilineTextAlignment(.center)
                }
                .padding(24)

                ScrollView {
                    VStack(spacing: 12) {
                        // Pro section
                        if let proMonthly = proMonthlyProduct {
                            VStack(spacing: 12) {
                                // Pro Monthly
                                proOptionCard(
                                    product: proMonthly,
                                    isSelected: selectedProductID == proMonthly.id
                                ) {
                                    selectedProductID = proMonthly.id
                                    showProAnnual = false
                                }

                                // Pro Annual (toggle visibility)
                                if let proAnnual = proAnnualProduct {
                                    if showProAnnual {
                                        proOptionCard(
                                            product: proAnnual,
                                            isSelected: selectedProductID == proAnnual.id,
                                            isSavings: true,
                                            savingsPercentage: 17
                                        ) {
                                            selectedProductID = proAnnual.id
                                        }
                                    }

                                    Button(action: { showProAnnual.toggle() }) {
                                        HStack {
                                            Text(showProAnnual ? "Hide annual option" : "Show annual option (save 17%)")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.orange)
                                            Spacer()
                                            Image(systemName: showProAnnual ? "chevron.up" : "chevron.down")
                                                .foregroundStyle(.orange)
                                        }
                                        .padding(12)
                                        .background(Color.orange.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                        }

                        Divider()
                            .padding(.vertical, 8)

                        // Family section
                        if let familyMonthly = familyMonthlyProduct {
                            VStack(spacing: 12) {
                                // Family Monthly
                                familyOptionCard(
                                    product: familyMonthly,
                                    isSelected: selectedProductID == familyMonthly.id
                                ) {
                                    selectedProductID = familyMonthly.id
                                    showFamilyAnnual = false
                                }

                                // Family Annual (toggle visibility)
                                if let familyAnnual = familyAnnualProduct {
                                    if showFamilyAnnual {
                                        familyOptionCard(
                                            product: familyAnnual,
                                            isSelected: selectedProductID == familyAnnual.id,
                                            isSavings: true,
                                            savingsPercentage: 17
                                        ) {
                                            selectedProductID = familyAnnual.id
                                        }
                                    }

                                    Button(action: { showFamilyAnnual.toggle() }) {
                                        HStack {
                                            Text(showFamilyAnnual ? "Hide annual option" : "Show annual option (save 17%)")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.orange)
                                            Spacer()
                                            Image(systemName: showFamilyAnnual ? "chevron.up" : "chevron.down")
                                                .foregroundStyle(.orange)
                                        }
                                        .padding(12)
                                        .background(Color.orange.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }

                // MARK: Footer
                VStack(spacing: 12) {
                    Button(action: purchaseSelected) {
                        if entitlementService.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(12)
                        } else {
                            Text("Subscribe")
                                .frame(maxWidth: .infinity)
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(12)
                        }
                    }
                    .background(Color.orange)
                    .cornerRadius(8)
                    .disabled(entitlementService.isLoading || selectedProductID == nil)

                    HStack(spacing: 12) {
                        Button(action: restorePurchases) {
                            Text("Restore Purchases")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.blue)
                        }

                        Divider()
                            .frame(height: 16)

                        Button(action: { print("Privacy Policy tapped") }) {
                            Text("Privacy")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.blue)
                        }

                        Divider()
                            .frame(height: 16)

                        Button(action: { print("Terms tapped") }) {
                            Text("Terms")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(.horizontal, 16)

                    Button(action: dismiss) {
                        Text("Not now")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
            }
        }
        .task {
            await loadProducts()
        }
        .alert("Purchase Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(purchaseError ?? "An unknown error occurred")
        }
    }

    @ViewBuilder
    private func proOptionCard(
        product: Product,
        isSelected: Bool,
        isSavings: Bool = false,
        savingsPercentage: Int = 0,
        action: @escaping () -> Void
    ) -> some View {
        Button { action() } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Pro")
                            .font(.headline)
                        Spacer()
                        if isSavings {
                            Text("Save \(savingsPercentage)%")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    Text("All Pro features")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(product.displayPrice)
                        .font(.headline)
                    Text(product.id.contains("monthly") ? "per month" : "per year")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .orange : .secondary)
            }
            .padding(12)
            .background(isSelected ? Color.orange.opacity(0.1) : Color(.secondarySystemGroupedBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
            )
        }
    }

    @ViewBuilder
    private func familyOptionCard(
        product: Product,
        isSelected: Bool,
        isSavings: Bool = false,
        savingsPercentage: Int = 0,
        action: @escaping () -> Void
    ) -> some View {
        Button { action() } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Family")
                                .font(.headline)
                            Label("Share with up to 6 people", systemImage: "person.2.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if isSavings {
                            Text("Save \(savingsPercentage)%")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(product.displayPrice)
                        .font(.headline)
                    Text(product.id.contains("monthly") ? "per month" : "per year")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .orange : .secondary)
            }
            .padding(12)
            .background(isSelected ? Color.orange.opacity(0.1) : Color(.secondarySystemGroupedBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
            )
        }
    }

    // MARK: - Actions

    private func loadProducts() async {
        await entitlementService.loadProducts()

        proMonthlyProduct = entitlementService.products.first { $0.id == ProductID.proMonthly }
        proAnnualProduct = entitlementService.products.first { $0.id == ProductID.proAnnual }
        familyMonthlyProduct = entitlementService.products.first { $0.id == ProductID.familyMonthly }
        familyAnnualProduct = entitlementService.products.first { $0.id == ProductID.familyAnnual }

        // Default to pro monthly
        if selectedProductID == nil {
            selectedProductID = proMonthlyProduct?.id
        }
    }

    private func purchaseSelected() {
        guard let productID = selectedProductID else { return }
        guard let product = entitlementService.products.first(where: { $0.id == productID }) else { return }

        Task {
            do {
                let transaction = try await entitlementService.purchase(product)
                if transaction != nil {
                    // Purchase succeeded, dismiss
                    dismiss()
                }
            } catch {
                purchaseError = error.localizedDescription
                showingError = true
            }
        }
    }

    private func restorePurchases() {
        Task {
            await entitlementService.restorePurchases()
        }
    }
}

#Preview {
    PaywallView(
        reason: .presentMode,
        entitlementService: EntitlementService(),
        dismiss: { }
    )
}
