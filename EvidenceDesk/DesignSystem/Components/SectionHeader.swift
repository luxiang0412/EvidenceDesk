import SwiftUI

/// Consistent section heading used across detail views.
///
/// No accessibility modifiers are applied: a plain `Text` is already exposed
/// with its own label, and wrapping it (`contain`/`combine`) was observed to
/// blank the label for VoiceOver and UI automation.
struct SectionHeader: View {
    let title: String
    var accessory: AnyView? = nil

    init(_ title: String, accessory: (() -> AnyView)? = nil) {
        self.title = title
        self.accessory = accessory?()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            // `title` is an English key; resolve it so Chinese UI is consistent
            // with the rest of the interface.
            Text(L10n.t(title))
                .font(DesignSystem.Typography.sectionTitle)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let accessory { accessory }
        }
    }
}
