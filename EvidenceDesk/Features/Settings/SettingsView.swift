import SwiftUI

/// The app's only settings screen: language.
///
/// It exists because the language override needs a home; the task brief only
/// allows a settings screen when there is something real to configure and
/// therefore only enables ⌘, when it does.
struct SettingsView: View {
    @Environment(\.designColors) private var colors
    private let settings = LanguageSettings.shared

    @State private var pending: AppLanguage = .system
    @State private var relaunchNeeded = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("Language")
                .font(DesignSystem.Typography.sectionTitle)

            Text("The interface language changes after you quit and reopen Evidence Desk. Research data, dates and your notes are never translated or altered.")
                .font(DesignSystem.Typography.secondary)
                .foregroundStyle(colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Picker("Language", selection: $pending) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.nativeName).tag(language)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
            .onChange(of: pending) { _, newValue in
                relaunchNeeded = settings.set(newValue)
            }

            if relaunchNeeded {
                HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "arrow.clockwise.circle")
                        .foregroundStyle(colors.accent)
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Relaunch to apply")
                            .font(DesignSystem.Typography.secondary)
                        Button("Quit Evidence Desk") {
                            NSApplication.shared.terminate(nil)
                        }
                        .controlSize(.small)
                    }
                }
                .padding(DesignSystem.Spacing.md)
                .background(colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.medium))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("settings.relaunchNotice")
            }

            Divider()

            Text("Evidence Desk stores everything on this Mac. It makes no network requests, and report contents follow the language you choose here.")
                .font(DesignSystem.Typography.metadata)
                .foregroundStyle(colors.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(width: 460, height: 320, alignment: .topLeading)
        .onAppear { pending = settings.language }
        .accessibilityIdentifier("settings.root")
    }
}
