import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    private let currencies = [
        "USD", "EUR", "GBP", "JPY", "CNY", "CAD", "AUD", "NZD",
        "CHF", "SEK", "NOK", "DKK", "PLN", "CZK", "HUF", "RON",
        "TRY", "AED", "SAR", "ILS", "INR", "SGD", "HKD", "KRW",
        "ZAR", "BRL", "MXN", "ARS", "CLP", "COP"
    ]

    @State private var defaultTaxRate = ""
    @State private var defaultReserveRate = ""
    @State private var reminderDay = 10
    @State private var reminderTime = Date()
    @State private var savedDefaultTaxRate = 0.0
    @State private var savedDefaultReserveRate = 0.0
    @State private var savedReminderDay = 10
    @State private var savedReminderHour = 9
    @State private var savedReminderMinute = 0

    @FocusState private var focusedField: Field?
    private let inactiveButtonOpacity = 0.45

    private enum Field: Hashable {
        case taxRate, reserveRate
    }

    private var taxSettingsDirty: Bool {
        abs(parse(defaultTaxRate) / 100 - savedDefaultTaxRate) > 0.0001 ||
        abs(parse(defaultReserveRate) / 100 - savedDefaultReserveRate) > 0.0001
    }

    private var reminderDirty: Bool {
        let current = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        return reminderDay != savedReminderDay ||
            (current.hour ?? 0) != savedReminderHour ||
            (current.minute ?? 0) != savedReminderMinute
    }

    private var nextAmount: Double {
        appState.taxRecords.first(where: { !$0.isPaid })?.amountDue ?? 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        profileCard
                        defaultsCard
                        reminderCard
                        notesCard
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 6)
                    .padding(.bottom, 120)
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture {
                    focusedField = nil
                    hideKeyboard()
                }
            }
            .navigationTitle(Text("settings.title"))
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear {
                loadSettingsState()
            }
            .onChange(of: appState.profile.taxationMode) { _ in
                appState.saveProfile()
            }
            .onChange(of: appState.profile.currencyCode) { _ in
                appState.saveProfile()
            }
        }
    }

    private var profileCard: some View {
        VStack(spacing: 12) {
            sectionHeader("settings.profile")

            VStack(alignment: .leading, spacing: 8) {
                Text("settings.mode")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                Picker("settings.mode", selection: $appState.profile.taxationMode) {
                    ForEach(TaxationMode.allCases) { mode in
                        Text(LocalizedStringKey(mode.localizedTitleKey)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("settings.currency")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                Picker("settings.currency", selection: $appState.profile.currencyCode) {
                    ForEach(currencies, id: \.self) { currency in
                        Text(currency).tag(currency)
                    }
                }
                .pickerStyle(.menu)
                .tint(Theme.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var defaultsCard: some View {
        VStack(spacing: 12) {
            sectionHeader("settings.defaults")

            settingsField(title: "settings.taxRate", text: $defaultTaxRate, field: .taxRate)
            settingsField(title: "settings.extraRate", text: $defaultReserveRate, field: .reserveRate)

            Button("settings.save.tax") {
                saveTaxDefaults()
            }
            .font(.system(size: 15, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(Color.black)
            .opacity(taxSettingsDirty ? 1 : inactiveButtonOpacity)
            .disabled(!taxSettingsDirty)
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("settings.language.note.title")
            Text("settings.language.note")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var reminderCard: some View {
        VStack(spacing: 12) {
            sectionHeader("tax.reminder.title")

            VStack(alignment: .leading, spacing: 8) {
                Text("tax.reminder.day")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)

                Picker("", selection: $reminderDay) {
                    ForEach(1...31, id: \.self) { day in
                        Text("\(day)").tag(day)
                    }
                }
                .pickerStyle(.menu)
                .tint(Theme.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            DatePicker("tax.reminder.time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
                .tint(Theme.accent)
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("tax.reminder.action") {
                let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
                let hour = components.hour ?? 9
                let minute = components.minute ?? 0
                UserDefaults.standard.set(reminderDay, forKey: "reminderDay")
                UserDefaults.standard.set(hour, forKey: "reminderHour")
                UserDefaults.standard.set(minute, forKey: "reminderMinute")
                UserDefaults.standard.set(reminderTime.timeIntervalSince1970, forKey: "reminderTime")
                Task {
                    await appState.scheduleTaxReminder(
                        amount: nextAmount,
                        currencyCode: appState.profile.currencyCode,
                        day: reminderDay,
                        hour: hour,
                        minute: minute
                    )
                }
                savedReminderDay = reminderDay
                savedReminderHour = hour
                savedReminderMinute = minute
                reminderTime = Calendar.current.date(
                    bySettingHour: savedReminderHour,
                    minute: savedReminderMinute,
                    second: 0,
                    of: Date()
                ) ?? reminderTime
            }
            .font(.system(size: 15, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(Color.black)
            .opacity(reminderDirty ? 1 : inactiveButtonOpacity)
            .disabled(!reminderDirty)
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(LocalizedStringKey(title))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
        }
    }

    private func settingsField(title: String, text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey(title))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            HStack(spacing: 8) {
                TextField("", text: text, prompt: Text("0").foregroundColor(.white.opacity(0.65)))
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: field)
                    .foregroundStyle(Theme.textPrimary)
                Text("%")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
            .padding(12)
            .background(Theme.cardMuted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func parse(_ value: String) -> Double {
        Double(value.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func saveTaxDefaults() {
        let tax = max(0, parse(defaultTaxRate) / 100)
        let reserve = max(0, parse(defaultReserveRate) / 100)
        appState.profile.defaultTaxRate = tax
        appState.profile.defaultReserveExtraRate = reserve
        appState.saveProfile()
        savedDefaultTaxRate = tax
        savedDefaultReserveRate = reserve
        defaultTaxRate = stripTrailingZeros(tax * 100)
        defaultReserveRate = stripTrailingZeros(reserve * 100)
        focusedField = nil
        hideKeyboard()
    }

    private func loadSettingsState() {
        savedDefaultTaxRate = appState.profile.defaultTaxRate
        savedDefaultReserveRate = appState.profile.defaultReserveExtraRate
        defaultTaxRate = stripTrailingZeros(savedDefaultTaxRate * 100)
        defaultReserveRate = stripTrailingZeros(savedDefaultReserveRate * 100)

        let storedDay = UserDefaults.standard.integer(forKey: "reminderDay")
        savedReminderDay = storedDay == 0 ? 10 : storedDay
        reminderDay = savedReminderDay

        let storedHour = UserDefaults.standard.object(forKey: "reminderHour") as? Int
        let storedMinute = UserDefaults.standard.object(forKey: "reminderMinute") as? Int
        if let hour = storedHour, let minute = storedMinute {
            savedReminderHour = min(max(hour, 0), 23)
            savedReminderMinute = min(max(minute, 0), 59)
        } else {
            let legacy = UserDefaults.standard.double(forKey: "reminderTime")
            if legacy > 0 {
                let legacyDate = Date(timeIntervalSince1970: legacy)
                let legacyComponents = Calendar.current.dateComponents([.hour, .minute], from: legacyDate)
                savedReminderHour = legacyComponents.hour ?? 9
                savedReminderMinute = legacyComponents.minute ?? 0
                UserDefaults.standard.set(savedReminderHour, forKey: "reminderHour")
                UserDefaults.standard.set(savedReminderMinute, forKey: "reminderMinute")
            } else {
                savedReminderHour = 9
                savedReminderMinute = 0
                UserDefaults.standard.set(savedReminderHour, forKey: "reminderHour")
                UserDefaults.standard.set(savedReminderMinute, forKey: "reminderMinute")
            }
        }

        reminderTime = Calendar.current.date(
            bySettingHour: savedReminderHour,
            minute: savedReminderMinute,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    private func stripTrailingZeros(_ number: Double) -> String {
        let value = String(format: "%.1f", number)
        return value.hasSuffix(".0") ? String(value.dropLast(2)) : value
    }
}
