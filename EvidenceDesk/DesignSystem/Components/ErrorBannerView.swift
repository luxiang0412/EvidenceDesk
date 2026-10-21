import SwiftUI

/// Non-blocking error message with an optional retry action.
struct ErrorBannerView: View {
    let message: String
    var retryTitle: String? = nil
    var retry: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(message)
                    .font(DesignSystem.Typography.secondary)
                    .accessibilityIdentifier("errorBanner.message")
                if let retryTitle, let retry {
                    Button(retryTitle, action: retry)
                        .controlSize(.small)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(DesignSystem.Spacing.md)
        .background(RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
            .fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
            .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
    }
}

/// Inline error text (used inside sheets/forms).
struct InlineErrorText: View {
    let text: String
    var body: some View {
        Text(text)
            .font(DesignSystem.Typography.metadata)
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
    }
}