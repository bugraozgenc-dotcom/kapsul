import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
  case general, appearance, history, sources, privacy, updates
  var id: Self { self }
  var title: String {
    switch self {
    case .general: return "Genel"
    case .appearance: return "Görünüm"
    case .history: return "Geçmiş"
    case .sources: return "Kaynaklarım"
    case .privacy: return "Gizlilik"
    case .updates: return "Güncellemeler"
    }
  }
  var icon: String {
    switch self {
    case .general: return "slider.horizontal.3"
    case .appearance: return "circle.lefthalf.filled"
    case .history: return "clock.arrow.circlepath"
    case .sources: return "globe"
    case .privacy: return "hand.raised"
    case .updates: return "arrow.down.circle"
    }
  }
}

struct SettingsCard<Content: View>: View {
  @ViewBuilder var content: () -> Content
  var body: some View {
    VStack(alignment: .leading, spacing: 12, content: content)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(18)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
      .overlay(RoundedRectangle(cornerRadius: 16).stroke(.primary.opacity(0.065), lineWidth: 1))
  }
}
