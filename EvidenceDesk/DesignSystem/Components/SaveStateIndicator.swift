import SwiftUI

/// Explicit save states. "Saved" is only shown after a successful save.
enum SaveState: Equatable {
    case idle
    case saving
    case saved
    case failed(String)
}

struct SaveStateIndicator: View {
    let state: SaveState

    var body: some View {
        switch state {
        case .idle:
            Text(L10n.t("Not saved")).foregroundStyle(.secondary)
        case .saving:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(L10n.t("Saving…"))
            }
            .foregroundStyle(.secondary)
        case .saved:
            // One explicit element: `Label` + identifier alone exposed an empty
            // accessibility label on this SDK (D-014).
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                Text(L10n.t("Saved"))
            }
            .foregroundStyle(.green)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.t("Saved"))
            .accessibilityIdentifier("saveState.saved")
        case .failed(let message):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(L10n.t("Save failed: %@", message))
            }
            .foregroundStyle(.red)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.t("Save failed: %@", message))
            .accessibilityIdentifier("saveState.failed")
        }
    }
}