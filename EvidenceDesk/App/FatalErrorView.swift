import SwiftUI

/// Shown only when the app cannot initialise its data store. Honest, with a
/// recovery path (retry), never a silent blank window.
@MainActor
struct FatalErrorView: View {
    let error: Error
    /// Called when the user asks to try opening the store again.
    var onRetry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text("Evidence Desk couldn't start its data store.")
                .font(DesignSystem.Typography.sectionTitle)
            Text(error.localizedDescription)
                .font(DesignSystem.Typography.secondary)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
            HStack {
                Button("Quit") { NSApp.terminate(nil) }
                if let onRetry {
                    Button("Try Again", action: onRetry)
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(DesignSystem.Spacing.xxl)
    }
}

/// Minimal NSApplication delegate so the app object is identifiable.
final class AppDelegate: NSObject, NSApplicationDelegate {}