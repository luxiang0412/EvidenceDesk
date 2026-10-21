import Foundation

/// A language the UI can be shown in.
///
/// Switching language changes `AppleLanguages` for this app's user defaults and
/// takes effect on the next launch. AppKit resolves the UI language from the
/// bundle's localizations at launch time; changing it live is not supported by
/// SwiftUI/AppKit in a way that survives every view (and forcing
/// `\.locale` on the root scene made the window fail to appear on macOS 27,
/// see docs/DECISIONS.md D-015).
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    /// Name shown in the picker, always in its own language so it is readable
    /// even when the current UI language differs.
    var nativeName: String {
        switch self {
        case .system: return String(localized: "Follow System Language")
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        }
    }
}

/// Persists the user's language choice and applies it to the app's defaults.
///
/// The value is stored twice on purpose:
/// - `appLanguage` keeps the explicit choice (including "follow system").
/// - `AppleLanguages` is what AppKit/SwiftUI actually honour on launch.
/// Deliberately a plain type (not `@Observable` injected through `@State`):
/// combining `@State` + `@Observable` + `@MainActor` in the `App` struct made
/// the main window fail to appear on macOS 27 (see docs/DECISIONS.md D-015).
/// Because a language change requires a relaunch anyway, observation buys
/// nothing here.
@MainActor
final class LanguageSettings {
    static let shared = LanguageSettings()
    nonisolated static let choiceKey = "appLanguage"

    private let defaults: UserDefaults

    /// Currently selected choice.
    private(set) var language: AppLanguage

    /// True when the stored `AppleLanguages` no longer matches the saved choice,
    /// i.e. a relaunch is needed for the change to be visible.
    private(set) var requiresRelaunch = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.string(forKey: Self.choiceKey).flatMap(AppLanguage.init(rawValue:)) ?? .system
        self.language = stored
        self.requiresRelaunch = Self.needsRelaunch(
            choice: stored,
            effective: defaults.stringArray(forKey: "AppleLanguages") ?? []
        )
    }

    /// Applies a new choice. Returns whether a relaunch is required.
    @discardableResult
    func set(_ newValue: AppLanguage) -> Bool {
        language = newValue
        defaults.set(newValue.rawValue, forKey: Self.choiceKey)
        switch newValue {
        case .system:
            defaults.removeObject(forKey: "AppleLanguages")
        case .english:
            defaults.set(["en"], forKey: "AppleLanguages")
        case .simplifiedChinese:
            defaults.set(["zh-Hans"], forKey: "AppleLanguages")
        }
        requiresRelaunch = Self.needsRelaunch(
            choice: newValue,
            effective: defaults.stringArray(forKey: "AppleLanguages") ?? []
        )
        return requiresRelaunch
    }

    /// Compares the saved choice with what AppKit will actually use next launch.
    nonisolated static func needsRelaunch(choice: AppLanguage, effective: [String]) -> Bool {
        switch choice {
        case .system:
            // AppKit writes the resolved system languages; any explicit single
            // language means an old override is still in place.
            return effective.count == 1 && (effective.first == "en" || effective.first == "zh-Hans")
        case .english:
            return effective.first != "en"
        case .simplifiedChinese:
            return effective.first != "zh-Hans"
        }
    }
}
