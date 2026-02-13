import SwiftUI

struct StatisticsEntry: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let amount: Double
}

struct StatisticsView: View {
    let titleKey: String
    let entries: [StatisticsEntry]
    let currencyCode: String

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    chartCard
                    legendCard
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
        }
        .navigationTitle(Text(LocalizedStringKey(titleKey)))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .statusBarHidden(true)
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("summary.chart.payments")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)

            if entries.isEmpty {
                Text("summary.chart.empty")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            } else {
                bars
            }
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var bars: some View {
        let maxValue = max(entries.map(\.amount).max() ?? 0, 1)

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Theme.accent)
                            .frame(width: 26, height: max(10, CGFloat(entry.amount / maxValue) * 140))

                        Text("\(index + 1)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(width: 34)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var legendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("summary.legend")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)

            if entries.isEmpty {
                Text("summary.chart.empty")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(Theme.accent)
                                .frame(width: 10, height: 10)

                            Text("\(index + 1).")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.textSecondary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Text(entry.subtitle)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Theme.textSecondary)
                            }

                            Spacer()

                            Text(money(entry.amount))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.accent)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Theme.cardMuted.opacity(0.9), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func money(_ amount: Double) -> String {
        let formatter = FormatterFactory.currency(code: currencyCode)
        return formatter.string(from: NSNumber(value: amount)) ?? "0"
    }
}
