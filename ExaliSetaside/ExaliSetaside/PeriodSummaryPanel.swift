import SwiftUI

struct PeriodSummaryFooter: View {
    let total: Double
    let currencyCode: String
    let actionTitleKey: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Text("summary.total")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                Text(money(total))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accent)
            }

            Spacer()

            Button(action: action) {
                Text(LocalizedStringKey(actionTitleKey))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.cardMuted, in: Capsule(style: .continuous))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func money(_ amount: Double) -> String {
        let formatter = FormatterFactory.currency(code: currencyCode)
        return formatter.string(from: NSNumber(value: amount)) ?? "0"
    }
}
