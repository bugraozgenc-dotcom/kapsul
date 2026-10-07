import SwiftUI

struct ClipboardEmptyState: View {
    @EnvironmentObject private var localization: AppLocalization
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date()
    var body: some View {
        VStack(spacing: 18) {
            Group {
                if reduceMotion { documentIcon }
                else {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                        let phase = timeline.date.timeIntervalSince(startedAt) * .pi * 2 / 3.6
                        documentIcon
                            .offset(y: sin(phase) * 5)
                            .rotationEffect(.degrees(sin(phase) * 2))
                    }
                }
            }.frame(width: 80, height: 80).accessibilityHidden(true)
            VStack(spacing: 8) {
                Text(localization.text("İlk kopyanı bekliyor")).font(.system(size: 20, weight: .semibold))
                Text(localization.text("Kopyala, burada bul.")).font(.system(size: 14)).foregroundStyle(.secondary)
            }
        }.foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private var documentIcon: some View {
        Image(systemName: "doc.on.clipboard").font(.system(size: 46, weight: .regular)).foregroundStyle(.tertiary)
    }
}
