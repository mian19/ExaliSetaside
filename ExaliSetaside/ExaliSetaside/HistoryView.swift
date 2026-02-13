import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var appState: AppState

    @State private var reminderDay = 10
    @State private var reminderTime = Date()

    private var unpaidTaxes: [TaxPaymentRecord] {
        appState.taxRecords.filter { !$0.isPaid }
    }

    private var paidTaxes: [TaxPaymentRecord] {
        appState.taxRecords.filter { $0.isPaid }
    }

    private var nextAmount: Double {
        unpaidTaxes.first?.amountDue ?? 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                GeometryReader { proxy in
                    ScrollView {
                        VStack(spacing: 14) {
                            reminderCard
                            sectionCard(title: "tax.unpaid.title", list: unpaidTaxes, canMarkPaid: true)
                            sectionCard(title: "tax.paid.title", list: paidTaxes, canMarkPaid: false)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: proxy.size.height, alignment: .top)
                        .padding(.horizontal, 14)
                        .padding(.top, 6)
                    }
                }
            }
            .navigationTitle(Text("screen.taxes.title"))
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private var reminderCard: some View {
        VStack(spacing: 10) {
            sectionTitle("tax.reminder.title")

            Picker("tax.reminder.day", selection: $reminderDay) {
                ForEach(1...28, id: \.self) { day in
                    Text("\(day)").tag(day)
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.accent)
            .frame(maxWidth: .infinity, alignment: .leading)

            DatePicker("tax.reminder.time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
                .tint(Theme.accent)
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("tax.reminder.action") {
                let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
                Task {
                    await appState.scheduleTaxReminder(
                        amount: nextAmount,
                        currencyCode: appState.profile.currencyCode,
                        day: reminderDay,
                        hour: components.hour ?? 9,
                        minute: components.minute ?? 0
                    )
                }
            }
            .font(.system(size: 15, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(Color.black)
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func sectionCard(title: String, list: [TaxPaymentRecord], canMarkPaid: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(title)

            if list.isEmpty {
                Text("tax.empty")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            } else {
                ForEach(list) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(item.periodLabel)
                                .foregroundStyle(Theme.textSecondary)
                            Spacer()
                            Text(money(item.amountDue))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.accent)
                        }

                        if canMarkPaid {
                            Button("tax.markPaid") {
                                appState.markTaxAsPaid(item.id)
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.success)
                        } else if let paidAt = item.paidAt {
                            Text("\(String(localized: "tax.paidAt")) \(paidAt.formatted(.dateTime.day().month().year()))")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .padding(12)
                    .background(Theme.cardMuted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
        let formatter = FormatterFactory.currency(code: appState.profile.currencyCode)
        return formatter.string(from: NSNumber(value: amount)) ?? "0"
    }
}
