import SwiftUI

struct RecordsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var filter: RecordFilter = .all

    private var filtered: [IncomeRecord] {
        switch filter {
        case .all: return appState.records
        case .paid: return appState.records.filter { $0.isPaid }
        case .unpaid: return appState.records.filter { !$0.isPaid }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 10) {
                    Picker("", selection: $filter) {
                        Text("orders.filter.all").tag(RecordFilter.all)
                        Text("orders.filter.paid").tag(RecordFilter.paid)
                        Text("orders.filter.unpaid").tag(RecordFilter.unpaid)
                    }
                    .pickerStyle(.segmented)
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
        }
    }

    private func deleteFiltered(at offsets: IndexSet) {
        let idsToDelete = offsets.compactMap { filtered[$0].id }
        let indexes = IndexSet(appState.records.enumerated().compactMap { idx, item in
            idsToDelete.contains(item.id) ? idx : nil
        })
        appState.removeRecords(at: indexes)
    }
}

private enum RecordFilter {
    case all
    case paid
    case unpaid
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
