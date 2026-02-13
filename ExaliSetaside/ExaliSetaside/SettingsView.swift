import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    private let currencies = ["USD", "EUR", "GBP", "MXN"]

    @State private var defaultTaxRate = ""
    @State private var defaultReserveRate = ""

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case taxRate, reserveRate
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        profileCard
                        defaultsCard
                        notesCard
                        saveButton
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 6)
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
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .onAppear {
                defaultTaxRate = stripTrailingZeros(appState.profile.defaultTaxRate * 100)
                defaultReserveRate = stripTrailingZeros(appState.profile.defaultReserveExtraRate * 100)
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
                .pickerStyle(.segmented)
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

    private var saveButton: some View {
        Button("settings.save") {
            appState.profile.defaultTaxRate = max(0, parse(defaultTaxRate) / 100)
            appState.profile.defaultReserveExtraRate = max(0, parse(defaultReserveRate) / 100)
            appState.saveProfile()
            focusedField = nil
            hideKeyboard()
        }
        .font(.system(size: 16, weight: .bold))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .foregroundStyle(Color.black)
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

    private func stripTrailingZeros(_ number: Double) -> String {
        let value = String(format: "%.1f", number)
        return value.hasSuffix(".0") ? String(value.dropLast(2)) : value
    }
}
