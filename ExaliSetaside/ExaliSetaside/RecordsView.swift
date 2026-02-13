import SwiftUI

struct RecordsView: View {
    @EnvironmentObject private var appState: AppState
    var onAddScreenVisibilityChange: (Bool) -> Void = { _ in }
    @State private var statusFilter: RecordStatusFilter = .all
    @State private var periodMode: PeriodMode = .thisMonth
    @State private var periodStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
    @State private var periodEnd = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
    @State private var showAddOperation = false

    private var filtered: [IncomeRecord] {
        appState.records.filter { record in
            statusFilter.matches(record: record) && matchesPeriod(record.date)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 10) {
                    Picker("", selection: $statusFilter) {
                        Text("orders.filter.all").tag(RecordStatusFilter.all)
                        Text("orders.filter.paid").tag(RecordStatusFilter.paid)
                        Text("orders.filter.unpaid").tag(RecordStatusFilter.unpaid)
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
                        Text("orders.empty")
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.top, 40)
                        Spacer()
                    } else {
                        List {
                            ForEach(filtered) { record in
                                OrderRow(record: record, currencyCode: appState.profile.currencyCode) {
                                    appState.toggleRecordPaid(record.id)
                                }
                                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                                .listRowBackground(Theme.background)
                            }
                            .onDelete(perform: deleteFiltered)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle(Text("screen.orders.title"))
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationDestination(isPresented: $showAddOperation) {
                OperationEntrySheet()
                    .environmentObject(appState)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                showAddOperation = true
            } label: {
                Text("add.record.action")
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(Color.black)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(Theme.background)
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
        .onChange(of: showAddOperation) { isShown in
            onAddScreenVisibilityChange(isShown)
        }
        .onAppear {
            onAddScreenVisibilityChange(false)
        }
        .onDisappear {
            onAddScreenVisibilityChange(false)
        }
    }

    private func deleteFiltered(at offsets: IndexSet) {
        let idsToDelete = offsets.compactMap { filtered[$0].id }
        let indexes = IndexSet(appState.records.enumerated().compactMap { idx, item in
            idsToDelete.contains(item.id) ? idx : nil
        })
        appState.removeRecords(at: indexes)
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

private enum RecordStatusFilter: Hashable {
    case all
    case paid
    case unpaid

    func matches(record: IncomeRecord) -> Bool {
        switch self {
        case .all:
            return true
        case .paid:
            return record.isPaid
        case .unpaid:
            return !record.isPaid
        }
    }
}

private enum PeriodMode: Hashable {
    case thisMonth
    case selected
}

private struct OrderRow: View {
    let record: IncomeRecord
    let currencyCode: String
    let togglePaid: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(record.clientName.isEmpty ? String(localized: "orders.untitled") : record.clientName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(money(record.amount))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accent)
            }

            HStack {
                Text(record.date.formatted(.dateTime.day().month(.abbreviated).year()))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)

                Text(record.isPaid ? "orders.status.paid" : "orders.status.unpaid")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        (record.isPaid ? Theme.success : Theme.warning).opacity(0.2),
                        in: Capsule(style: .continuous)
                    )
                    .foregroundStyle(record.isPaid ? Theme.success : Theme.warning)

                Spacer()
                Button(record.isPaid ? "orders.mark.unpaid" : "orders.mark.paid") {
                    togglePaid()
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(record.isPaid ? Theme.warning : Theme.success)
            }
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func money(_ amount: Double) -> String {
        let formatter = FormatterFactory.currency(code: currencyCode)
        return formatter.string(from: NSNumber(value: amount)) ?? "0"
    }
}
