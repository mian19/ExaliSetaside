import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var appState: AppState

    @State private var statusFilter: TaxStatusFilter = .all
    @State private var periodMode: PeriodMode = .thisMonth
    @State private var periodStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
    @State private var periodEnd = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()

    private var filtered: [TaxPaymentRecord] {
        appState.taxRecords.filter { item in
            statusFilter.matches(item: item) && matchesPeriod(item.periodStart)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 10) {
                    Picker("", selection: $statusFilter) {
                        Text("tax.filter.all").tag(TaxStatusFilter.all)
                        Text("tax.filter.unpaid").tag(TaxStatusFilter.unpaid)
                        Text("tax.filter.paid").tag(TaxStatusFilter.paid)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 14)

                    HStack(spacing: 8) {
                        Picker("period.mode", selection: $periodMode) {
                            Text("period.thisMonth").tag(PeriodMode.thisMonth)
                            Text("period.selected").tag(PeriodMode.selected)
                        }
                        .pickerStyle(.menu)
                        .tint(Theme.accent)

                        if periodMode == .selected {
                            MonthYearPicker(titleKey: "period.from", selection: $periodStart)

                            MonthYearPicker(titleKey: "period.to", selection: $periodEnd)
                        }
                    }
                    .padding(.horizontal, 14)

                    if filtered.isEmpty {
                        Text("tax.empty")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.top, 40)
                        Spacer()
                    } else {
                        List {
                            ForEach(filtered) { item in
                                taxRow(item)
                                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                                    .listRowBackground(Theme.background)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle(Text("screen.taxes.title"))
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onChange(of: periodStart) { newValue in
            periodStart = monthStart(newValue)
            if periodEnd < periodStart {
                periodEnd = periodStart
            }
        }
        .onChange(of: periodEnd) { newValue in
            periodEnd = monthStart(newValue)
            if periodEnd < periodStart {
                periodStart = periodEnd
            }
        }
    }

    private func taxRow(_ item: TaxPaymentRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.periodLabel)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(money(item.amountDue))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accent)
            }

            HStack {
                Text(item.isPaid ? "tax.filter.paid" : "tax.filter.unpaid")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        (item.isPaid ? Theme.success : Theme.warning).opacity(0.2),
                        in: Capsule(style: .continuous)
                    )
                    .foregroundStyle(item.isPaid ? Theme.success : Theme.warning)

                Spacer()

                Button(item.isPaid ? "tax.markUnpaid" : "tax.markPaid") {
                    appState.toggleTaxPaidStatus(item.id)
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(item.isPaid ? Theme.warning : Theme.success)
            }

            if let paidAt = item.paidAt, item.isPaid {
                Text("\(String(localized: "tax.paidAt")) \(paidAt.formatted(.dateTime.day().month().year()))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func money(_ amount: Double) -> String {
        let formatter = FormatterFactory.currency(code: appState.profile.currencyCode)
        return formatter.string(from: NSNumber(value: amount)) ?? "0"
    }

    private func matchesPeriod(_ date: Date) -> Bool {
        let calendar = Calendar.current
        switch periodMode {
        case .thisMonth:
            return calendar.isDate(date, equalTo: Date(), toGranularity: .month)
        case .selected:
            let start = monthStart(periodStart)
            let end = monthStart(periodEnd)
            guard let endExclusive = calendar.date(byAdding: .month, value: 1, to: end) else { return true }
            return date >= start && date < endExclusive
        }
    }

    private func monthStart(_ value: Date) -> Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: value)) ?? value
    }
}

private enum TaxStatusFilter: Hashable {
    case all
    case paid
    case unpaid

    func matches(item: TaxPaymentRecord) -> Bool {
        switch self {
        case .all:
            return true
        case .paid:
            return item.isPaid
        case .unpaid:
            return !item.isPaid
        }
    }
}

private enum PeriodMode: Hashable {
    case thisMonth
    case selected
}
