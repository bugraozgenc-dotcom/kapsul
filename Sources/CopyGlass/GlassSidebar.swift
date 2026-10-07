import SwiftUI

struct GlassSidebar: View {
    @Binding var selection: String
    @EnvironmentObject var catalog: SourceCatalog
    @EnvironmentObject private var localization: AppLocalization
    @Namespace private var glassNamespace
    @FocusState private var focusedRow: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var rows: [String] {
        ["Tümü", "Sabitlenenler"] + ClipKind.allCases.filter { $0 != .instagram }.map(\.rawValue) + ClipSource.allCases.map(\.rawValue) + catalog.customs.map { "custom:" + $0.id.uuidString }
    }
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 5) {
                    row("Tümü") { Label(localization.text("Tümü"), systemImage: "square.grid.2x2") }
                    row("Sabitlenenler") { Label(localization.text("Sabitlenenler"), systemImage: "pin") }
                    sectionTitle("İÇERİK TÜRLERİ")
                    ForEach(ClipKind.allCases.filter { $0 != .instagram }, id: \.self) { kind in
                        row(kind.rawValue) { Label(localization.text(kind.rawValue), systemImage: kind.icon) }
                    }
                    sectionTitle("KAYNAKLAR")
                    ForEach(ClipSource.allCases, id: \.self) { source in
                        row(source.rawValue) { GroupLabel(kind: nil, source: source) }
                    }
                    if !catalog.customs.isEmpty {
                        sectionTitle("KAYNAKLARIM")
                        ForEach(catalog.customs) { source in
                            row("custom:" + source.id.uuidString) { Label(source.name, systemImage: "globe") }
                        }
                    }
                }.padding(.horizontal, 12).padding(.vertical, 8)
            }.onMoveCommand { direction in
                guard direction == .up || direction == .down else { return }
                let index = rows.firstIndex(of: focusedRow ?? selection) ?? 0
                let next = min(max(index + (direction == .down ? 1 : -1), 0), rows.count - 1)
                select(rows[next])
                focusedRow = rows[next]
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { proxy.scrollTo(rows[next]) }
            }
        }
    }
    private func sectionTitle(_ title: String) -> some View {
        Text(localization.text(title)).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
            .padding(.horizontal, 10).padding(.top, 20).padding(.bottom, 6)
            .accessibilityAddTraits(.isHeader)
    }
    private func select(_ id: String) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.8)) { selection = id }
    }
    private func row<Content: View>(_ id: String, @ViewBuilder label: @escaping () -> Content) -> some View {
        GlassSidebarRow(selected: selection == id, namespace: glassNamespace, action: { select(id) }, label: label)
            .id(id).focused($focusedRow, equals: id)
    }
}

private struct GlassSidebarRow<Content: View>: View {
    let selected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    @ViewBuilder let label: () -> Content
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Button(action: action) {
            label().labelStyle(.titleAndIcon)
                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                .lineLimit(1).minimumScaleFactor(0.85)
                .foregroundStyle(selected ? Color.primary : Color.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12).frame(height: 38)
                .background {
                    if selected {
                        SidebarGlassSelection().matchedGeometryEffect(id: "sidebar-selection", in: namespace)
                    } else if hovering {
                        RoundedRectangle(cornerRadius: 12).fill(.primary.opacity(0.055))
                    }
                }.contentShape(RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(GlassSidebarPressStyle())
            .onHover { inside in withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) { hovering = inside } }
            .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

private struct SidebarGlassSelection: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        Group {
            if reduceTransparency {
                RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor))
                    .overlay(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.18)))
            } else if #available(macOS 26.0, *) {
                RoundedRectangle(cornerRadius: 12).fill(.clear)
                    .glassEffect(.regular.tint(.blue.opacity(0.12)).interactive(), in: RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.1)))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12).stroke(
                LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.1), .blue.opacity(0.22)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.75)
        }
        .shadow(color: .black.opacity(0.09), radius: 5, y: 2)
        .allowsHitTesting(false)
    }
}

private struct GlassSidebarPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
    }
}
