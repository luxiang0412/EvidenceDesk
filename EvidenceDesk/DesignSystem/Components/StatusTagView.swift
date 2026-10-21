import SwiftUI

/// A labelled status tag. Colour is never the only signal — the text label is
/// always present, satisfying VoiceOver and accessibility checks.
struct StatusTagView: View {
    let text: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(DesignSystem.Typography.metadata)
            .foregroundStyle(color)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: DesignSystem.Radius.small))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
    }
}

extension View {
    @ViewBuilder
    func evidenceTypeTag(_ type: EvidenceType, colors: DesignSystem.Colors) -> some View {
        let color = switch type {
        case .fact: colors.fact
        case .interpretation: colors.inference
        case .hypothesis: colors.hypothesis
        case .unresolved: colors.unresolved
        }
        StatusTagView(text: type.displayName, systemImage: type.systemImage, color: color)
    }

    @ViewBuilder
    func findingStatusTag(_ status: FindingStatus, colors: DesignSystem.Colors) -> some View {
        let color = switch status {
        case .draft: Color.secondary
        case .active: colors.accent
        case .superseded: colors.tertiaryText
        }
        StatusTagView(text: status.displayName, systemImage: status == .draft ? "pencil" : status == .active ? "circle.fill" : "arrow.uturn.backward", color: color)
    }

    @ViewBuilder
    func relationTypeTag(_ relation: RelationType, colors: DesignSystem.Colors) -> some View {
        let color = switch relation {
        case .supports: colors.success
        case .contradicts: colors.danger
        case .context: colors.inference
        }
        StatusTagView(text: relation.displayName, systemImage: relation.systemImage, color: color)
    }
}