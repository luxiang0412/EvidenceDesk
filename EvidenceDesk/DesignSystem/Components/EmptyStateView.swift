import SwiftUI

/// Page-level empty state: explains the purpose and offers a clear first step.
///
/// The icon and both text lines are exposed as **one** accessibility element
/// with a composed label. Two reasons:
///  1. VoiceOver announces one coherent sentence instead of three fragments.
///  2. On this SDK, attaching an identifier to a standalone `Text` inside this
///     hierarchy made SwiftUI expose an *empty* label (docs/DECISIONS.md D-014),
///     which also broke UI automation. A wrapper element with an explicit label
///     is stable.
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            VStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: systemImage)
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(DesignSystem.Typography.sectionTitle)
                Text(message)
                    .font(DesignSystem.Typography.secondary)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title). \(message)")
            .accessibilityIdentifier("emptyState")

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, DesignSystem.Spacing.sm)
                    .accessibilityIdentifier("emptyState.action")
            }
        }
        .padding(DesignSystem.Spacing.xl)
    }
}
