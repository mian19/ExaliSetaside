import Foundation

struct TaxProfile: Codable {
    var countryCode: String
    var taxationMode: TaxationMode
    var defaultTaxRate: Double
    var defaultReserveExtraRate: Double
    var currencyCode: String

    static let `default` = TaxProfile(
        countryCode: "US",
        taxationMode: .freelancer,
        defaultTaxRate: 0.25,
        defaultReserveExtraRate: 0.03,
        currencyCode: "USD"
    )
}

enum TaxationMode: String, CaseIterable, Codable, Identifiable {
    case freelancer
    case selfEmployed
    case contractor

    var id: String { rawValue }

    var localizedTitleKey: String {
        switch self {
        case .freelancer:
            return "mode.freelancer"
        case .selfEmployed:
            return "mode.selfEmployed"
        case .contractor:
            return "mode.contractor"
        }
    }
}

struct TaxPaymentRecord: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    let periodStart: Date
    let periodLabel: String
    let taxableIncome: Double
    let amountDue: Double
    var isPaid: Bool
    var paidAt: Date?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        periodStart: Date,
        periodLabel: String,
        taxableIncome: Double,
        amountDue: Double,
        isPaid: Bool = false,
        paidAt: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.periodStart = periodStart
        self.periodLabel = periodLabel
        self.taxableIncome = taxableIncome
        self.amountDue = amountDue
        self.isPaid = isPaid
        self.paidAt = paidAt
    }
}

struct IncomeRecord: Identifiable, Codable {
    let id: UUID
    var date: Date
    var clientName: String
    var amount: Double
    var isPaid: Bool
    var note: String

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        clientName: String,
        amount: Double,
        isPaid: Bool = true,
        note: String = ""
    ) {
        self.id = id
        self.date = date
        self.clientName = clientName
        self.amount = amount
        self.isPaid = isPaid
        self.note = note
    }
}

struct TaxResult {
    let taxableIncome: Double
    let estimatedTax: Double
    let reserveExtra: Double
    let totalSetAside: Double
}

enum TaxCalculator {
    static func estimate(
        grossIncome: Double,
        deductions: Double,
        taxRate: Double,
        extraReserveRate: Double
    ) -> TaxResult {
        let safeIncome = max(0, grossIncome)
        let safeDeductions = max(0, deductions)
        let taxable = max(0, safeIncome - safeDeductions)
        let tax = taxable * max(0, taxRate)
        let extra = taxable * max(0, extraReserveRate)
        return TaxResult(
            taxableIncome: taxable,
            estimatedTax: tax,
            reserveExtra: extra,
            totalSetAside: tax + extra
        )
    }
}
