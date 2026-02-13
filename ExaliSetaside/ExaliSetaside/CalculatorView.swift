import SwiftUI

struct CalculatorView: View {
    @EnvironmentObject private var appState: AppState
    private let debugLayoutColors = false

    @State private var clientName = ""
    @State private var amountText = ""
    @State private var recordDate = Date()
    @State private var isPaid = true

    @State private var deductionsText = ""
    @State private var taxRateText = "25"
    @State private var socialRateText = "5"
    @State private var extraRateText = "3"

    @FocusState private var amountFocused: Bool

    private var currentMonthRecords: [IncomeRecord] {
        let calendar = Calendar.current
        let now = Date()
        return appState.records.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
    }

    private var grossIncome: Double {
        currentMonthRecords.reduce(0) { $0 + $1.amount }
    }

    private var deductions: Double {
        max(0, Double(deductionsText.replacingOccurrences(of: ",", with: ".")) ?? 0)
    }

    private var taxRate: Double { max(0, (Double(taxRateText.replacingOccurrences(of: ",", with: ".")) ?? 0) / 100.0) }
    private var socialRate: Double { max(0, (Double(socialRateText.replacingOccurrences(of: ",", with: ".")) ?? 0) / 100.0) }
    private var extraRate: Double { max(0, (Double(extraRateText.replacingOccurrences(of: ",", with: ".")) ?? 0) / 100.0) }

    private var result: TaxResult {
        TaxCalculator.estimate(
            grossIncome: grossIncome,
            deductions: deductions,
            taxRate: taxRate + socialRate,
            extraReserveRate: extraRate
        )
    }

    private var currencyFormatter: NumberFormatter {
        FormatterFactory.currency(code: appState.profile.currencyCode)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        addRecordCard
                        monthlySummaryCard
                        saveTaxCard
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 6)
                    .padding(.bottom, 96)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture { hideKeyboard() }
            }
            .navigationTitle(Text("screen.add.title"))
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .onAppear {
                taxRateText = strip(appState.profile.defaultTaxRate * 100)
                extraRateText = strip(appState.profile.defaultReserveExtraRate * 100)
            }
        }
    }

    private var addRecordCard: some View {
        VStack(spacing: 10) {
            sectionTitle("add.record.section")

            textInputField("add.record.client", text: $clientName, placeholderKey: "add.record.client.placeholder")
            amountField

            DatePicker("add.record.date", selection: $recordDate, displayedComponents: [.date])
                .datePickerStyle(.compact)
                .tint(Theme.accent)
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("add.record.paid", isOn: $isPaid)
                .tint(Theme.accent)
                .foregroundStyle(Theme.textPrimary)

            Button("add.record.action") {
                let amount = max(0, Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0)
                guard amount > 0 else { return }
                let record = IncomeRecord(
                    date: recordDate,
                    clientName: clientName.trimmingCharacters(in: .whitespacesAndNewlines),
                    amount: amount,
                    isPaid: isPaid
                )
                appState.add(record: record)
                clientName = ""
                amountText = ""
                isPaid = true
            }
            .font(.system(size: 15, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(Color.black)
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            if debugLayoutColors {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.orange, lineWidth: 2)
            }
        }
    }

    private var monthlySummaryCard: some View {
        VStack(spacing: 10) {
            sectionTitle("add.calc.section")

            statRow("add.calc.ordersCount", "\(currentMonthRecords.count)")
            statRow("add.calc.gross", money(grossIncome))

            numericInputField("add.calc.deductions", text: $deductionsText)

            HStack(spacing: 8) {
                percentField("field.taxRate", $taxRateText)
                percentField("field.socialRate", $socialRateText)
                percentField("field.extraRate", $extraRateText)
            }

            Divider().overlay(Theme.textSecondary.opacity(0.25))
            statRow("result.total", money(result.totalSetAside), highlight: true)
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            if debugLayoutColors {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.purple, lineWidth: 2)
            }
        }
    }

    private var saveTaxCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("add.tax.section")
            Text("add.tax.hint")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textSecondary)

            Button("add.tax.action") {
                let monthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
                let periodLabel = DateFormatter.localizedString(from: monthStart, dateStyle: .medium, timeStyle: .none)
                let tax = TaxPaymentRecord(
                    periodStart: monthStart,
                    periodLabel: periodLabel,
                    taxableIncome: result.taxableIncome,
                    amountDue: result.totalSetAside
                )
                appState.addTaxRecord(tax)
            }
            .disabled(result.totalSetAside <= 0)
            .font(.system(size: 15, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.cardMuted, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(Theme.textPrimary)
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            if debugLayoutColors {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.yellow, lineWidth: 2)
            }
        }
    }

    private func textInputField(_ key: String, text: Binding<String>, placeholderKey: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey(key))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            TextField("", text: text, prompt: Text(LocalizedStringKey(placeholderKey)).foregroundColor(.white.opacity(0.65)))
                .textInputAutocapitalization(.words)
                .keyboardType(.default)
                .autocorrectionDisabled()
                .foregroundStyle(Theme.textPrimary)
                .padding(12)
                .background(Theme.cardMuted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func numericInputField(_ key: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey(key))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            TextField("", text: text, prompt: Text("0").foregroundColor(.white.opacity(0.65)))
                .keyboardType(.decimalPad)
                .foregroundStyle(Theme.textPrimary)
                .padding(12)
                .background(Theme.cardMuted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("add.record.amount")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            TextField("", text: $amountText, prompt: Text("0").foregroundColor(.white.opacity(0.65)))
                .keyboardType(.decimalPad)
                .focused($amountFocused)
                .foregroundStyle(Theme.textPrimary)
                .padding(12)
                .background(Theme.cardMuted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func percentField(_ key: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey(key))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            HStack {
                TextField("", text: text, prompt: Text("0").foregroundColor(.white.opacity(0.65)))
                    .keyboardType(.decimalPad)
                    .foregroundStyle(Theme.textPrimary)
                Text("%")
                    .foregroundStyle(Theme.accent)
            }
            .padding(12)
            .background(Theme.cardMuted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(maxWidth: .infinity)
    }

    private func statRow(_ key: String, _ value: String, highlight: Bool = false) -> some View {
        HStack {
            Text(LocalizedStringKey(key))
                .foregroundStyle(highlight ? Theme.textPrimary : Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: highlight ? 21 : 15, weight: .bold, design: .rounded))
                .foregroundStyle(highlight ? Theme.accent : Theme.textPrimary)
        }
    }

    private func sectionTitle(_ key: String) -> some View {
        HStack {
            Text(LocalizedStringKey(key))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
        }
    }

    private func money(_ amount: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: amount)) ?? "0"
    }

    private func strip(_ value: Double) -> String {
        let str = String(format: "%.1f", value)
        return str.hasSuffix(".0") ? String(str.dropLast(2)) : str
    }
}
