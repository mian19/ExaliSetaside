import SwiftUI

struct MonthYearPicker: View {
    let titleKey: String
    @Binding var selection: Date

    private let monthsBack = 36
    private let monthsForward = 0

    private var monthOptions: [Date] {
        let calendar = Calendar.current
        let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()

        return (-monthsBack...monthsForward).compactMap { offset in
            calendar.date(byAdding: .month, value: offset, to: currentMonth)
        }
    }

    var body: some View {
        Picker(LocalizedStringKey(titleKey), selection: $selection) {
            ForEach(monthOptions, id: \.self) { month in
                Text(month.formatted(.dateTime.month(.abbreviated).year()))
                    .tag(month)
            }
        }
        .pickerStyle(.menu)
        .tint(Theme.accent)
    }
}
