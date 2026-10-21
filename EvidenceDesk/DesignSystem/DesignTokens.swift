import SwiftUI

/// Central semantic design tokens for Evidence Desk.
///
/// Rule: views must not scatter arbitrary colors or sizes. Use these tokens and
/// system semantic colors/fonts where possible. Keep color contrast accessible
/// in both light and dark appearances (checked in P6 visual QA).
enum DesignSystem {
    // MARK: - Spacing (base 4pt)

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Radius

    enum Radius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 10
        static let large: CGFloat = 12
    }

    // MARK: - Layout

    enum Layout {
        static let rowHeight: CGFloat = 28
        static let sidebarWidth: CGFloat = 240
        static let inspectorWidth: CGFloat = 280
        static let minWindowWidth: CGFloat = 980
        static let minWindowHeight: CGFloat = 640
        static let defaultWindowWidth: CGFloat = 1180
        static let defaultWindowHeight: CGFloat = 780
    }

    // MARK: - Color tokens

    struct Colors {
        // Surfaces map to system semantic colors so both appearances are handled.
        let canvas: Color
        let surface: Color
        let elevatedSurface: Color
        let separator: Color

        let primaryText: Color
        let secondaryText: Color
        let tertiaryText: Color
        let accent: Color

        // Semantic evidence/finding states – never the *only* signal, labels always present.
        let fact: Color
        let inference: Color
        let hypothesis: Color
        let unresolved: Color
        let danger: Color
        let success: Color
    }

    /// Accessor that returns tokens tuned to the current appearance.
    static func colors(for scheme: ColorScheme) -> Colors {
        switch scheme {
        case .light:
            return lightColors
        case .dark:
            return darkColors
        @unknown default:
            return lightColors
        }
    }

    static let lightColors = Colors(
        canvas: Color(nsColor: .windowBackgroundColor),
        surface: Color(nsColor: .controlBackgroundColor),
        elevatedSurface: Color(nsColor: .underPageBackgroundColor),
        separator: Color(nsColor: .separatorColor),
        primaryText: Color(nsColor: .labelColor),
        secondaryText: Color(nsColor: .secondaryLabelColor),
        tertiaryText: Color(nsColor: .tertiaryLabelColor),
        accent: Color(nsColor: .controlAccentColor),
        fact: Color(red: 0.11, green: 0.42, blue: 0.22),
        inference: Color(red: 0.16, green: 0.35, blue: 0.55),
        hypothesis: Color(red: 0.55, green: 0.35, blue: 0.08),
        unresolved: Color(red: 0.45, green: 0.16, blue: 0.18),
        danger: .red,
        success: .green
    )

    static let darkColors = Colors(
        canvas: Color(nsColor: .windowBackgroundColor),
        surface: Color(nsColor: .controlBackgroundColor),
        elevatedSurface: Color(nsColor: .underPageBackgroundColor),
        separator: Color(nsColor: .separatorColor),
        primaryText: Color(nsColor: .labelColor),
        secondaryText: Color(nsColor: .secondaryLabelColor),
        tertiaryText: Color(nsColor: .tertiaryLabelColor),
        accent: Color(nsColor: .controlAccentColor),
        fact: Color(red: 0.42, green: 0.78, blue: 0.5),
        inference: Color(red: 0.45, green: 0.68, blue: 0.9),
        hypothesis: Color(red: 0.85, green: 0.69, blue: 0.35),
        unresolved: Color(red: 0.85, green: 0.52, blue: 0.55),
        danger: Color(nsColor: .systemRed),
        success: Color(nsColor: .systemGreen)
    )

    // MARK: - Typography (system fonts, semantic roles)

    enum Typography {
        static let pageTitle = Font.system(.largeTitle, design: .default).weight(.bold)
        static let sectionTitle = Font.system(.title3, design: .default).weight(.semibold)
        static let body = Font.system(.body)
        static let secondary = Font.system(.callout)
        static let metadata = Font.system(.caption).weight(.medium)
        static let monospacedSmall = Font.system(.caption, design: .monospaced)
    }
}

/// Convenience environment accessor for views.
struct DesignTokensKey: EnvironmentKey {
    static let defaultValue: DesignSystem.Colors = DesignSystem.lightColors
}

extension EnvironmentValues {
    var designColors: DesignSystem.Colors {
        get { self[DesignTokensKey.self] }
        set { self[DesignTokensKey.self] = newValue }
    }
}

/// View modifier that injects appearance-aware design colors.
struct DesignColorsModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content.environment(\.designColors, DesignSystem.colors(for: scheme))
    }
}

extension View {
    /// Apply appearance-aware design tokens to the subtree.
    func designAware() -> some View {
        modifier(DesignColorsModifier())
    }
}