import Foundation

/// Runtime string lookup for values that reach SwiftUI as `String` instead of
/// `LocalizedStringKey` (enum display names, component parameters, error
/// messages, accessibility labels).
///
/// Keys are the English source strings that also appear in
/// `Resources/Localizable.xcstrings`, so a missing translation degrades to
/// English rather than to a raw key. Regenerate the catalogue with
/// `python3 scripts/build-localization.py`.
enum L10n {
    /// Looks up `key` in the app's current localisation.
    static func t(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }

    /// Formats a localised format string (`%@`, `%lld`, …).
    static func t(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: t(key), arguments: arguments)
    }
}
