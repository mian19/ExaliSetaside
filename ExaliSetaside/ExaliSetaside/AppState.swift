import Foundation
import SwiftUI
import Combine
import UserNotifications

@MainActor
final class AppState: ObservableObject {
    @Published var profile: TaxProfile
    @Published var records: [IncomeRecord]
    @Published var taxRecords: [TaxPaymentRecord]

    private let profileKey = "taxProfile"
    private let recordsKey = "incomeRecords"
    private let taxRecordsKey = "taxRecords"

    init() {
        if let profileData = UserDefaults.standard.data(forKey: profileKey),
           let decoded = try? JSONDecoder().decode(TaxProfile.self, from: profileData) {
            profile = decoded
        } else {
            profile = .default
        }

        if let recordsData = UserDefaults.standard.data(forKey: recordsKey),
           let decoded = try? JSONDecoder().decode([IncomeRecord].self, from: recordsData) {
            records = decoded.sorted { $0.date > $1.date }
        } else {
            records = []
        }

        if let taxData = UserDefaults.standard.data(forKey: taxRecordsKey),
           let decoded = try? JSONDecoder().decode([TaxPaymentRecord].self, from: taxData) {
            taxRecords = decoded.sorted { $0.createdAt > $1.createdAt }
        } else {
            taxRecords = []
        }

        recomputeTaxRecordsFromPaidIncome()
    }

    func saveProfile() {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: profileKey)
        recomputeTaxRecordsFromPaidIncome()
    }

    func add(record: IncomeRecord) {
        records.insert(record, at: 0)
        persistRecords()
        recomputeTaxRecordsFromPaidIncome()
    }

    func removeRecords(at offsets: IndexSet) {
        records.remove(atOffsets: offsets)
        persistRecords()
        recomputeTaxRecordsFromPaidIncome()
    }

    func toggleRecordPaid(_ id: UUID) {
        guard let idx = records.firstIndex(where: { $0.id == id }) else { return }
        records[idx].isPaid.toggle()
        persistRecords()
        recomputeTaxRecordsFromPaidIncome()
    }

    func addTaxRecord(_ taxRecord: TaxPaymentRecord) {
        taxRecords.insert(taxRecord, at: 0)
        persistTaxRecords()
    }

    func markTaxAsPaid(_ id: UUID) {
        guard let idx = taxRecords.firstIndex(where: { $0.id == id }) else { return }
        taxRecords[idx].isPaid = true
        taxRecords[idx].paidAt = Date()
        persistTaxRecords()
    }

    func toggleTaxPaidStatus(_ id: UUID) {
        guard let idx = taxRecords.firstIndex(where: { $0.id == id }) else { return }
        taxRecords[idx].isPaid.toggle()
        taxRecords[idx].paidAt = taxRecords[idx].isPaid ? Date() : nil
        persistTaxRecords()
    }

    func removeTaxRecords(at offsets: IndexSet) {
        taxRecords.remove(atOffsets: offsets)
        persistTaxRecords()
    }

    func scheduleTaxReminder(amount: Double, currencyCode: String, day: Int, hour: Int, minute: Int) async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])

        center.removePendingNotificationRequests(withIdentifiers: ["taxPaymentReminder"])

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 2
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"

        let content = UNMutableNotificationContent()
        content.title = String(localized: "reminder.tax.title")
        let bodyFormat = String(localized: "reminder.tax.body %@")
        content.body = String(format: bodyFormat, formatted)
        content.sound = .default

        var date = DateComponents()
        date.day = min(max(day, 1), 28)
        date.hour = min(max(hour, 0), 23)
        date.minute = min(max(minute, 0), 59)

        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(
            identifier: "taxPaymentReminder",
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }

    private func persistRecords() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: recordsKey)
    }

    private func persistTaxRecords() {
        guard let data = try? JSONEncoder().encode(taxRecords) else { return }
        UserDefaults.standard.set(data, forKey: taxRecordsKey)
    }

    private func recomputeTaxRecordsFromPaidIncome() {
        let calendar = Calendar.current
        let paidRecords = records.filter { $0.isPaid }

        let existingByMonth: [Date: TaxPaymentRecord] = taxRecords.reduce(into: [:]) { partial, item in
            let key = monthStart(item.periodStart, calendar: calendar)
            let current = partial[key]
            if current == nil || item.createdAt > (current?.createdAt ?? .distantPast) {
                partial[key] = item
            }
        }

        let groupedByMonth = Dictionary(grouping: paidRecords) { monthStart($0.date, calendar: calendar) }
        let generated = groupedByMonth.keys.sorted(by: >).map { start -> TaxPaymentRecord in
            let monthRecords = groupedByMonth[start] ?? []
            let gross = monthRecords.reduce(0) { $0 + $1.amount }
            let result = TaxCalculator.estimate(
                grossIncome: gross,
                deductions: 0,
                taxRate: profile.defaultTaxRate,
                extraReserveRate: profile.defaultReserveExtraRate
            )
            let periodLabel = DateFormatter.localizedString(from: start, dateStyle: .medium, timeStyle: .none)
            let existing = existingByMonth[start]

            return TaxPaymentRecord(
                id: existing?.id ?? UUID(),
                createdAt: existing?.createdAt ?? Date(),
                periodStart: start,
                periodLabel: periodLabel,
                taxableIncome: result.taxableIncome,
                amountDue: result.totalSetAside,
                isPaid: existing?.isPaid ?? false,
                paidAt: existing?.paidAt
            )
        }

        taxRecords = generated
        persistTaxRecords()
    }

    private func monthStart(_ value: Date, calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: value)) ?? value
    }
}
