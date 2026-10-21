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
            Text("Not saved").foregroundStyle(.secondary)
        case .saving:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Saving…")
            }
            .foregroundStyle(.secondary)
        case .saved:
            Label("Saved", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityLabel("Saved")
                .accessibilityIdentifier("saveState.saved")
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .accessibilityLabel("Save failed: \(message)")
                .accessibilityIdentifier("saveState.failed")
        }
    }
}