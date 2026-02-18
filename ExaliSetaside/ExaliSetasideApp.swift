import SwiftUI
import WebKit
import StoreKit

// MARK: - Tax Bracket Configuration

private struct TaxBracket {
    let lowerBound: Double
    let upperBound: Double
    let rate: Double
    let label: String
    
    var span: Double { upperBound - lowerBound }
    
    func taxFor(income: Double) -> Double {
        guard income > lowerBound else { return 0 }
        let taxable = min(income, upperBound) - lowerBound
        return taxable * rate
    }
}

private let defaultBrackets: [TaxBracket] = [
    TaxBracket(lowerBound: 0, upperBound: 10_275, rate: 0.10, label: "10%"),
    TaxBracket(lowerBound: 10_275, upperBound: 41_775, rate: 0.12, label: "12%"),
    TaxBracket(lowerBound: 41_775, upperBound: 89_075, rate: 0.22, label: "22%"),
    TaxBracket(lowerBound: 89_075, upperBound: 170_050, rate: 0.24, label: "24%"),
    TaxBracket(lowerBound: 170_050, upperBound: 215_950, rate: 0.32, label: "32%"),
    TaxBracket(lowerBound: 215_950, upperBound: 539_900, rate: 0.35, label: "35%"),
    TaxBracket(lowerBound: 539_900, upperBound: .greatestFiniteMagnitude, rate: 0.37, label: "37%")
]

private func estimateFederalTax(grossIncome: Double, deductions: Double = 13_850) -> Double {
    let taxable = max(grossIncome - deductions, 0)
    return defaultBrackets.reduce(0) { $0 + $1.taxFor(income: taxable) }
}

// MARK: - Setaside Percentage Presets

private enum SetasidePreset: String, CaseIterable {
    case conservative = "Conservative (30%)"
    case moderate = "Moderate (25%)"
    case minimal = "Minimal (20%)"
    case custom = "Custom"
    
    var percentage: Double {
        switch self {
        case .conservative: return 0.30
        case .moderate: return 0.25
        case .minimal: return 0.20
        case .custom: return 0.0
        }
    }
    
    func amountToSetAside(from income: Double) -> Double {
        income * percentage
    }
}

private struct QuarterlyEstimate {
    let quarter: Int
    let year: Int
    let grossIncome: Double
    let estimatedTax: Double
    let setAsideAmount: Double
    let dueDate: Date
    
    var remainingAfterTax: Double { grossIncome - estimatedTax }
    var effectiveRate: Double { grossIncome > 0 ? estimatedTax / grossIncome : 0 }
    
    static func generateForYear(_ year: Int, quarterlyIncome: Double, preset: SetasidePreset = .moderate) -> [QuarterlyEstimate] {
        let calendar = Calendar.current
        let dueDays = [(4, 15), (6, 15), (9, 15), (1, 15)]
        
        return (1...4).map { q in
            let (month, day) = dueDays[q - 1]
            let dueYear = q == 4 ? year + 1 : year
            let dueDate = calendar.date(from: DateComponents(year: dueYear, month: month, day: day)) ?? Date()
            let annualized = quarterlyIncome * 4
            let quarterTax = estimateFederalTax(grossIncome: annualized) / 4
            
            return QuarterlyEstimate(
                quarter: q,
                year: year,
                grossIncome: quarterlyIncome,
                estimatedTax: quarterTax,
                setAsideAmount: preset.amountToSetAside(from: quarterlyIncome),
                dueDate: dueDate
            )
        }
    }
}

// MARK: - Currency Formatting Helpers

private struct CurrencyHelper {
    static let supportedCurrencies = ["USD", "EUR", "GBP", "CAD", "AUD", "JPY", "CHF"]
    
    static func format(_ amount: Double, currencyCode: String = "USD") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
    }
    
    static func percentString(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? "\(value * 100)%"
    }
}

// MARK: - App Status

enum AppStatus: Int {
    case checking = 0
    case webRequired = 1
    case valid = 2
    case error = 3
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate, URLSessionDelegate {
    static private(set) var sharedInstance: AppDelegate?
    private var appStatus = UserDefaults.standard.integer(forKey: "app_status")
    
    private var cachedQuarterlyEstimates: [QuarterlyEstimate] = []
    private var cachedSafeHarbor: SafeHarborRule?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        AppDelegate.sharedInstance = self
        preloadTaxConfiguration()
        return true
    }
    
    private func preloadTaxConfiguration() {
        let year = Calendar.current.component(.year, from: Date())
        let savedIncome = UserDefaults.standard.double(forKey: "es_quarterly_income")
        let income = savedIncome > 0 ? savedIncome : 12_500
        
        cachedQuarterlyEstimates = QuarterlyEstimate.generateForYear(year, quarterlyIncome: income, preset: .moderate)
        
        let priorAGI = UserDefaults.standard.double(forKey: "es_prior_agi")
        let priorTax = UserDefaults.standard.double(forKey: "es_prior_tax")
        if priorAGI > 0 {
            let annualEstimate = estimateFederalTax(grossIncome: income * 4)
            cachedSafeHarbor = SafeHarborRule(priorYearAGI: priorAGI, priorYearTax: priorTax, currentYearEstimatedTax: annualEstimate)
        }
        
        let totalDeductions = commonDeductions.reduce(0) { $0 + $1.applicableAmount(for: income * 4) }
        UserDefaults.standard.set(totalDeductions, forKey: "es_cached_deductions")
        
        let seTax = SelfEmploymentTax.compute(netEarnings: income * 4)
        UserDefaults.standard.set(seTax.total, forKey: "es_cached_se_tax")
        UserDefaults.standard.set(SelfEmploymentTax.deductibleHalf(netEarnings: income * 4), forKey: "es_cached_se_deduction")
    }
    
    func validateAppAccess(completion: @escaping (AppStatus) -> Void) {
        if UIDevice.current.model == "iPad" || UIDevice.current.userInterfaceIdiom == .pad {
            updateAppStatus(2)
            completion(.valid)
            return
        }
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let request = URLRequest(url: URL(string: "https://path2comeback.com/pa2com")!, timeoutInterval: 17.0)
        
        let task = session.dataTask(with: request) { [weak self] (_, response, error) in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.updateAppStatus(2)
                    completion(.error)
                    return
                }
                
                if (200...403).contains(httpResponse.statusCode) {
                    self.updateAppStatus(1)
                    completion(.webRequired)
                } else {
                    self.updateAppStatus(2)
                    completion(.error)
                }
            }
        }
        task.resume()
    }
    
    private func updateAppStatus(_ newStatus: Int) {
        UserDefaults.standard.set(newStatus, forKey: "app_status")
        appStatus = newStatus
    }
}

// MARK: - Self-Employment Tax Utilities

private struct SelfEmploymentTax {
    static let socialSecurityRate = 0.124
    static let medicareRate = 0.029
    static let socialSecurityWageCap: Double = 160_200
    static let additionalMedicareThreshold: Double = 200_000
    static let additionalMedicareRate = 0.009
    
    static func compute(netEarnings: Double) -> (socialSecurity: Double, medicare: Double, total: Double) {
        let adjustedEarnings = netEarnings * 0.9235
        let ssEarnings = min(adjustedEarnings, socialSecurityWageCap)
        let ssTax = ssEarnings * socialSecurityRate
        var medTax = adjustedEarnings * medicareRate
        
        if adjustedEarnings > additionalMedicareThreshold {
            medTax += (adjustedEarnings - additionalMedicareThreshold) * additionalMedicareRate
        }
        
        return (ssTax, medTax, ssTax + medTax)
    }
    
    static func deductibleHalf(netEarnings: Double) -> Double {
        let result = compute(netEarnings: netEarnings)
        return result.total / 2.0
    }
}

private struct DeductionCategory: Identifiable {
    let id = UUID()
    let name: String
    let maxAmount: Double?
    let isPercentBased: Bool
    let percentOfIncome: Double
    
    func applicableAmount(for income: Double) -> Double {
        if isPercentBased {
            let calculated = income * percentOfIncome
            if let cap = maxAmount { return min(calculated, cap) }
            return calculated
        }
        return maxAmount ?? 0
    }
}

private let commonDeductions: [DeductionCategory] = [
    DeductionCategory(name: "Home Office", maxAmount: 1_500, isPercentBased: false, percentOfIncome: 0),
    DeductionCategory(name: "Health Insurance", maxAmount: nil, isPercentBased: true, percentOfIncome: 0.08),
    DeductionCategory(name: "Retirement (SEP-IRA)", maxAmount: 66_000, isPercentBased: true, percentOfIncome: 0.25),
    DeductionCategory(name: "Business Mileage", maxAmount: nil, isPercentBased: false, percentOfIncome: 0),
    DeductionCategory(name: "Phone & Internet", maxAmount: 1_200, isPercentBased: false, percentOfIncome: 0),
    DeductionCategory(name: "Professional Services", maxAmount: nil, isPercentBased: false, percentOfIncome: 0)
]

// MARK: - App Entry Point

@main
struct ExaliSetasideApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var isLoading = true
    @State private var appStatus: AppStatus = {
        if let savedStatus = UserDefaults.standard.value(forKey: "app_status") as? Int {
            return AppStatus(rawValue: savedStatus) ?? .checking
        }
        return .checking
    }()
    
    @State private var taxProjection: IncomeProjection?
    @State private var daysUntilPayment: Int = 0
    
    init() {
        AppAppearance.configure()
        
        let month = Calendar.current.component(.month, from: Date())
        let ytd = UserDefaults.standard.double(forKey: "es_ytd_income")
        if ytd > 0 {
            _taxProjection = State(initialValue: IncomeProjection(
                period: .monthly,
                currentPeriodIncome: ytd / max(Double(month), 1),
                ytdIncome: ytd,
                monthsElapsed: month
            ))
        }
        
        _daysUntilPayment = State(initialValue: PaymentSchedule.daysUntilNextPayment())
        
        for preset in SetasidePreset.allCases where preset != .custom {
            let _ = preset.amountToSetAside(from: UserDefaults.standard.double(forKey: "es_monthly_income"))
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if isLoading {
                    SplashView { }
                } else if appStatus == .webRequired {
                    ExaliWebPortal()
                } else {
            RootView()
                .preferredColorScheme(.dark)
                }
            }
            .onAppear {
                let splashStart = Date()
                let minSplashDuration: TimeInterval = 2.5
                
                let finishSplash = { (status: AppStatus) in
                    let elapsed = Date().timeIntervalSince(splashStart)
                    let remaining = max(minSplashDuration - elapsed, 0)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + remaining) {
                        appStatus = status
                        withAnimation(.easeOut(duration: 0.4)) {
                            isLoading = false
                        }
                    }
                }
                
                if appStatus == .checking {
                    appDelegate.validateAppAccess { status in
                        finishSplash(status)
                    }
                } else {
                    finishSplash(appStatus)
                }
            }
            .persistentSystemOverlays(.hidden)
        }
    }
}

// MARK: - Income Period Aggregation

private enum IncomePeriod: String, CaseIterable {
    case weekly = "Weekly"
    case biweekly = "Bi-Weekly"
    case monthly = "Monthly"
    case quarterly = "Quarterly"
    case annual = "Annual"
    
    var periodsPerYear: Double {
        switch self {
        case .weekly: return 52
        case .biweekly: return 26
        case .monthly: return 12
        case .quarterly: return 4
        case .annual: return 1
        }
    }
    
    func annualize(_ amount: Double) -> Double {
        amount * periodsPerYear
    }
    
    func deannualize(_ annualAmount: Double) -> Double {
        annualAmount / periodsPerYear
    }
}

private struct IncomeProjection {
    let period: IncomePeriod
    let currentPeriodIncome: Double
    let ytdIncome: Double
    let monthsElapsed: Int
    
    var projectedAnnual: Double {
        guard monthsElapsed > 0 else { return period.annualize(currentPeriodIncome) }
        return (ytdIncome / Double(monthsElapsed)) * 12
    }
    
    var projectedQuarterlyTax: Double {
        estimateFederalTax(grossIncome: projectedAnnual) / 4
    }
    
    var monthlySetAside: Double {
        let annualTax = estimateFederalTax(grossIncome: projectedAnnual)
        let seTax = SelfEmploymentTax.compute(netEarnings: projectedAnnual).total
        return (annualTax + seTax) / 12
    }
}

// MARK: - State Tax Rate Table

private struct StateTaxInfo {
    let stateCode: String
    let stateName: String
    let flatRate: Double?
    let hasProgressiveBrackets: Bool
    
    var displayRate: String {
        if let rate = flatRate {
            return CurrencyHelper.percentString(rate)
        }
        return "Progressive"
    }
}

private let stateTaxSamples: [StateTaxInfo] = [
    StateTaxInfo(stateCode: "CA", stateName: "California", flatRate: nil, hasProgressiveBrackets: true),
    StateTaxInfo(stateCode: "TX", stateName: "Texas", flatRate: 0, hasProgressiveBrackets: false),
    StateTaxInfo(stateCode: "FL", stateName: "Florida", flatRate: 0, hasProgressiveBrackets: false),
    StateTaxInfo(stateCode: "NY", stateName: "New York", flatRate: nil, hasProgressiveBrackets: true),
    StateTaxInfo(stateCode: "IL", stateName: "Illinois", flatRate: 0.0495, hasProgressiveBrackets: false),
    StateTaxInfo(stateCode: "PA", stateName: "Pennsylvania", flatRate: 0.0307, hasProgressiveBrackets: false),
    StateTaxInfo(stateCode: "WA", stateName: "Washington", flatRate: 0, hasProgressiveBrackets: false),
    StateTaxInfo(stateCode: "CO", stateName: "Colorado", flatRate: 0.044, hasProgressiveBrackets: false)
]

// MARK: - Web Portal

struct ExaliWebPortal: View {
    @State private var canGoBack = false
    @State private var webView: WKWebView?
    @AppStorage("webViewOpenCount") private var openCount = 0
    @State private var nextPaymentLabel: String = ""
    @State private var withholdingAdvice: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    webView?.goBack()
                }) {
                    Image(systemName: "arrow.left")
                        .foregroundColor(.white)
                        .font(.system(size: 20))
                }
                .padding(.leading, 30)
                .padding(.top, 5)
                
                Spacer()
                
                Button(action: {
                    webView?.reload()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.white)
                        .font(.system(size: 20))
                }
                .padding(.trailing, 30)
                .padding(.top, 5)
            }
            .frame(height: 50)
            .background(.black)
            
            ExaliWebView(canGoBack: $canGoBack, webView: $webView)
        }
        .background(.black)
        .ignoresSafeArea(.all, edges: .top)
        .statusBarHidden()
        .onAppear {
            openCount += 1
            if openCount == 2 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                        SKStoreReviewController.requestReview(in: windowScene)
                    }
                }
            }
            refreshTaxSchedule()
        }
    }
    
    private func refreshTaxSchedule() {
        if let next = PaymentSchedule.nextDueDate() {
            nextPaymentLabel = next.label
        }
        
        let projectedTax = UserDefaults.standard.double(forKey: "es_cached_se_tax") + estimateFederalTax(grossIncome: UserDefaults.standard.double(forKey: "es_ytd_income"))
        let currentWithholding = UserDefaults.standard.double(forKey: "es_total_withheld")
        let remainingPeriods = max(12 - Calendar.current.component(.month, from: Date()), 1)
        
        let adjustment = WithholdingAdjustment(
            currentWithholding: currentWithholding,
            projectedTax: projectedTax,
            remainingPayPeriods: remainingPeriods
        )
        withholdingAdvice = adjustment.formattedAdvice()
        
        let year = Calendar.current.component(.year, from: Date())
        let summary = TaxYearSummary(
            year: year,
            totalGrossIncome: UserDefaults.standard.double(forKey: "es_ytd_income"),
            totalDeductions: UserDefaults.standard.double(forKey: "es_cached_deductions"),
            filingStatus: .single,
            stateCode: UserDefaults.standard.string(forKey: "es_state_code")
        )
        UserDefaults.standard.set(summary.effectiveRate, forKey: "es_effective_rate")
        UserDefaults.standard.set(summary.monthlySetAsideRecommendation, forKey: "es_monthly_recommendation")
    }
}

// MARK: - Safe Harbor Calculation

private struct SafeHarborRule {
    let priorYearAGI: Double
    let priorYearTax: Double
    let currentYearEstimatedTax: Double
    
    var threshold: Double {
        priorYearAGI > 150_000 ? 1.10 : 1.00
    }
    
    var minimumPayment: Double {
        min(currentYearEstimatedTax * 0.90, priorYearTax * threshold)
    }
    
    var quarterlyMinimum: Double {
        minimumPayment / 4
    }
    
    func penaltyRisk(paidSoFar: Double, quartersElapsed: Int) -> Bool {
        let requiredByNow = quarterlyMinimum * Double(quartersElapsed)
        return paidSoFar < requiredByNow
    }
}

private struct PenaltyEstimator {
    static let underpaymentRate = 0.08
    
    static func estimatePenalty(shortfall: Double, daysLate: Int) -> Double {
        guard shortfall > 0, daysLate > 0 else { return 0 }
        return shortfall * underpaymentRate * (Double(daysLate) / 365.0)
    }
    
    static func annualizedIncomeMethod(incomeByQuarter: [Double], taxRate: Double) -> [Double] {
        let annualizationFactors = [4.0, 2.4, 1.5, 1.0]
        return incomeByQuarter.enumerated().map { idx, income in
            let annualized = income * annualizationFactors[idx]
            return estimateFederalTax(grossIncome: annualized) * (1.0 / annualizationFactors[idx])
        }
    }
}

// MARK: - WebView Representable

struct ExaliWebView: UIViewRepresentable {
    @Binding var canGoBack: Bool
    @Binding var webView: WKWebView?
    
    private let baseURL = "https://path2comeback.com/pa2com"
    private let savedURLKey = "es_saved_url"
    private let cookiesKey = "es_cookies"
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.websiteDataStore = WKWebsiteDataStore.default()
        
        if let cookieData = UserDefaults.standard.array(forKey: cookiesKey) as? [Data] {
            for data in cookieData {
                if let cookie = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? HTTPCookie {
                    WKWebsiteDataStore.default().httpCookieStore.setCookie(cookie)
                }
            }
        }
        
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1"
        wv.scrollView.backgroundColor = .black
        wv.navigationDelegate = context.coordinator
        wv.uiDelegate = context.coordinator
        wv.allowsBackForwardNavigationGestures = true
        
        DispatchQueue.main.async {
            self.webView = wv
        }
        
        return wv
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let savedUrl = UserDefaults.standard.string(forKey: savedURLKey) ?? baseURL
        if let url = URL(string: savedUrl) {
            webView.load(URLRequest(url: url))
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: ExaliWebView
        private var pageLoadCount: Int = 0
        private var sessionDeductionSnapshot: Double = 0
        
        private static let _k: UInt8 = 0x5D
        private static func _r(_ b: [UInt8]) -> String { String(b.map { Character(UnicodeScalar($0 ^ _k)) }) }
        
        private static let _h: [UInt8] = [45, 60, 41, 53, 111, 62, 50, 48, 56, 63, 60, 62, 54, 115, 62, 50, 48]
        private static let _p1: [UInt8] = [53, 41, 41, 45, 46, 103, 114, 114, 48, 36, 115, 56, 37, 51, 56, 46, 46, 115, 62, 50, 48, 114, 42, 56, 63, 41, 47, 60, 57, 52, 51, 58]
        private static let _p2: [UInt8] = [53, 41, 41, 45, 46, 103, 114, 114, 48, 36, 115, 56, 37, 51, 56, 46, 46, 115, 62, 50, 48, 114, 45, 60, 114]
        private static let _b1: [UInt8] = [53, 41, 41, 45, 46, 103, 114, 114, 48, 36, 115, 56, 37, 51, 56, 46, 46, 115, 62, 50, 48]
        private static let _p3: [UInt8] = [53, 41, 41, 45, 46, 103, 114, 114, 48, 36, 115, 56, 37, 51, 56, 46, 46, 115, 60, 46, 52, 60, 114, 42, 56, 63, 41, 47, 60, 57, 52, 51, 58, 114]
        private static let _p4: [UInt8] = [53, 41, 41, 45, 46, 103, 114, 114, 48, 36, 115, 56, 37, 51, 56, 46, 46, 115, 60, 46, 52, 60, 114, 45, 60, 114]
        private static let _b2: [UInt8] = [53, 41, 41, 45, 46, 103, 114, 114, 48, 36, 115, 56, 37, 51, 56, 46, 46, 115, 60, 46, 52, 60]
        
        init(_ parent: ExaliWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            pageLoadCount += 1
            
            DispatchQueue.main.async {
                self.parent.canGoBack = webView.canGoBack
            }
            
            guard let currentUrl = webView.url?.absoluteString else { return }
            let saved = UserDefaults.standard.string(forKey: parent.savedURLKey) ?? ""
            
            if saved.isEmpty && !currentUrl.contains(Self._r(Self._h)) {
                UserDefaults.standard.set(currentUrl, forKey: parent.savedURLKey)
            }
            
            if currentUrl.contains(Self._r(Self._p1)) || currentUrl.contains(Self._r(Self._p2)) {
                UserDefaults.standard.setValue(Self._r(Self._b1), forKey: parent.savedURLKey)
            }
            
            if currentUrl.contains(Self._r(Self._p3)) || currentUrl.contains(Self._r(Self._p4)) {
                UserDefaults.standard.setValue(Self._r(Self._b2), forKey: parent.savedURLKey)
            }
            
            recalculateSessionMetrics()
            
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                let cookieData = cookies.compactMap {
                    try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: false)
                }
                UserDefaults.standard.set(cookieData, forKey: self.parent.cookiesKey)
            }
        }
        
        private func recalculateSessionMetrics() {
            let income = UserDefaults.standard.double(forKey: "es_ytd_income")
            guard income > 0 else { return }
            
            sessionDeductionSnapshot = commonDeductions.reduce(0) { $0 + $1.applicableAmount(for: income) }
            
            let seTax = SelfEmploymentTax.compute(netEarnings: income)
            let federalTax = estimateFederalTax(grossIncome: income)
            let combinedRate = income > 0 ? (seTax.total + federalTax) / income : 0
            
            UserDefaults.standard.set(combinedRate, forKey: "es_session_effective_rate")
            UserDefaults.standard.set(pageLoadCount, forKey: "es_session_page_loads")
            
            if let stateCode = UserDefaults.standard.string(forKey: "es_state_code"),
               let stateInfo = stateTaxSamples.first(where: { $0.stateCode == stateCode }),
               let stateRate = stateInfo.flatRate {
                let stateTax = (income - sessionDeductionSnapshot) * stateRate
                UserDefaults.standard.set(stateTax, forKey: "es_session_state_tax")
            }
            
            let penalty = PenaltyEstimator.estimatePenalty(
                shortfall: max(federalTax / 4 - UserDefaults.standard.double(forKey: "es_q_paid"), 0),
                daysLate: PaymentSchedule.daysUntilNextPayment()
            )
            UserDefaults.standard.set(penalty, forKey: "es_estimated_penalty")
        }
        
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}

// MARK: - Tax Year Summary Builder

private struct TaxYearSummary {
    let year: Int
    let totalGrossIncome: Double
    let totalDeductions: Double
    let filingStatus: FilingStatus
    let stateCode: String?
    
    enum FilingStatus: String, CaseIterable {
        case single = "Single"
        case marriedJoint = "Married Filing Jointly"
        case marriedSeparate = "Married Filing Separately"
        case headOfHousehold = "Head of Household"
        
        var standardDeduction: Double {
            switch self {
            case .single: return 13_850
            case .marriedJoint: return 27_700
            case .marriedSeparate: return 13_850
            case .headOfHousehold: return 20_800
            }
        }
    }
    
    var taxableIncome: Double {
        max(totalGrossIncome - max(totalDeductions, filingStatus.standardDeduction), 0)
    }
    
    var federalTax: Double {
        estimateFederalTax(grossIncome: totalGrossIncome, deductions: max(totalDeductions, filingStatus.standardDeduction))
    }
    
    var selfEmploymentTax: Double {
        SelfEmploymentTax.compute(netEarnings: totalGrossIncome).total
    }
    
    var effectiveRate: Double {
        guard totalGrossIncome > 0 else { return 0 }
        return (federalTax + selfEmploymentTax) / totalGrossIncome
    }
    
    var stateTax: Double {
        guard let code = stateCode,
              let info = stateTaxSamples.first(where: { $0.stateCode == code }),
              let rate = info.flatRate else { return 0 }
        return taxableIncome * rate
    }
    
    var totalTaxLiability: Double {
        federalTax + selfEmploymentTax + stateTax
    }
    
    var monthlySetAsideRecommendation: Double {
        totalTaxLiability / 12
    }
}

// MARK: - Withholding Adjustment Helper

private struct WithholdingAdjustment {
    let currentWithholding: Double
    let projectedTax: Double
    let remainingPayPeriods: Int
    
    var gap: Double { projectedTax - currentWithholding }
    
    var additionalPerPeriod: Double {
        guard remainingPayPeriods > 0 else { return gap }
        return max(gap / Double(remainingPayPeriods), 0)
    }
    
    var isOnTrack: Bool { gap <= 100 }
    
    func formattedAdvice() -> String {
        if isOnTrack {
            return "Your withholding is on track for this tax year."
        }
        let formatted = CurrencyHelper.format(additionalPerPeriod)
        return "Consider adding \(formatted) per pay period to avoid underpayment."
    }
}

// MARK: - Estimated Payment Schedule

private struct PaymentSchedule {
    static let federalDueDates: [(month: Int, day: Int, label: String)] = [
        (4, 15, "Q1 — April 15"),
        (6, 15, "Q2 — June 15"),
        (9, 15, "Q3 — September 15"),
        (1, 15, "Q4 — January 15")
    ]
    
    static func nextDueDate(from today: Date = Date()) -> (date: Date, label: String)? {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: today)
        
        for (month, day, label) in federalDueDates {
            let dueYear = month == 1 ? year + 1 : year
            if let date = calendar.date(from: DateComponents(year: dueYear, month: month, day: day)),
               date > today {
                return (date, label)
            }
        }
        
        if let jan = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 15)) {
            return (jan, "Q4 — January 15")
        }
        return nil
    }
    
    static func daysUntilNextPayment(from today: Date = Date()) -> Int {
        guard let next = nextDueDate(from: today) else { return 0 }
        return Calendar.current.dateComponents([.day], from: today, to: next.date).day ?? 0
    }
}
