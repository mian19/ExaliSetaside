import Foundation

enum PeriodFilter: String, CaseIterable, Identifiable {
    case thisMonth
    case last3Months
    case thisYear
    case allTime

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .thisMonth: return "period.thisMonth"
        case .last3Months: return "period.last3Months"
        case .thisYear: return "period.thisYear"
        case .allTime: return "period.allTime"
        }
    }

    func matches(date: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .thisMonth:
            return calendar.isDate(date, equalTo: now, toGranularity: .month)
        case .last3Months:
            guard let start = calendar.date(byAdding: .month, value: -2, to: calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now) else {
                return true
            }
            return date >= start
        case .thisYear:
            return calendar.isDate(date, equalTo: now, toGranularity: .year)
        case .allTime:
            return true
        }
    }
}
