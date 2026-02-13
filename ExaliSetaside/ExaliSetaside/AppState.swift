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
    }

    func saveProfile() {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: profileKey)
    }

    func add(record: IncomeRecord) {
        records.insert(record, at: 0)
        persistRecords()
    }

    func removeRecords(at offsets: IndexSet) {
        records.remove(atOffsets: offsets)
        persistRecords()
    }

    func toggleRecordPaid(_ id: UUID) {
        guard let idx = records.firstIndex(where: { $0.id == id }) else { return }
        records[idx].isPaid.toggle()
        persistRecords()
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
}
