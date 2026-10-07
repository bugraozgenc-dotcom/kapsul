import SwiftUI

/// Shared copy feedback for cards and the image preview.
struct CopyFeedbackButton: View {
    var prominent = false
    let action: () -> Bool
    @EnvironmentObject private var localization: AppLocalization
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var copied = false
    @State private var animationTrigger = 0
    @State private var resetTask: Task<Void, Never>?

    var body: some View {
        Button {
            guard action() else { return }
            resetTask?.cancel()
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                copied = true
                animationTrigger += 1
            }
            resetTask = Task { @MainActor in
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { copied = false }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                    .contentTransition(reduceMotion ? .opacity : .symbolEffect(.replace))
                    .symbolEffect(.bounce, options: .nonRepeating, value: reduceMotion ? 0 : animationTrigger)
                    .font(.system(size: 15, weight: .semibold))
                Text(localization.text(copied ? "Kopyalandı" : "Kopyala"))
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1).minimumScaleFactor(0.85)
            }
            .foregroundStyle(copied ? Color.green : (prominent ? Color.white : Color.secondary))
            .frame(width: prominent ? 124 : 108, height: prominent ? 38 : 28)
            .background {
                RoundedRectangle(cornerRadius: prominent ? 11 : 8)
                    .fill(copied ? Color.green.opacity(0.16) : (prominent ? Color.blue : Color.clear))
            }
            .overlay {
                RoundedRectangle(cornerRadius: prominent ? 11 : 8)
                    .stroke(copied ? Color.green.opacity(0.35) : Color.clear, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
            .help(localization.text("Panoya kopyala"))
            .accessibilityLabel(localization.text(copied ? "Kopyalandı" : "Kopyala"))
            .onDisappear { resetTask?.cancel() }
    }
}
