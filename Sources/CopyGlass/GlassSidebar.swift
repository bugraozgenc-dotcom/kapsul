import SwiftUI

struct GlassSidebar: View {
    @Binding var selection: String
    @EnvironmentObject private var store: ClipboardStore
    @EnvironmentObject var catalog: SourceCatalog
    @EnvironmentObject private var localization: AppLocalization
    @State private var scrollFrame = CGRect.zero
    @Namespace private var glassNamespace
    @FocusState private var focusedRow: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private struct SidebarStats {
        var counts: [String: Int] = [:]
        var latest: [String: Date] = [:]
    }
    private var stats: SidebarStats {
        var result = SidebarStats()
        for clip in store.clips {
            var ids = ["Tümü", clip.kind.rawValue]
            if clip.pinned { ids.append("Sabitlenenler") }
            ids += (clip.collectionIDs ?? []).map { "collection:" + $0.uuidString }
            if let custom = catalog.customSource(for: clip.value) { ids.append("custom:" + custom.id.uuidString) }
            else if let source = clip.groupSource { ids.append(source.rawValue) }
            for id in Set(ids) {
                result.counts[id, default: 0] += 1
                result.latest[id] = max(result.latest[id] ?? .distantPast, clip.date)
            }
        }
        return result
    }
    private func orderedSources(_ stats: SidebarStats) -> [ClipSource] {
        ClipSource.allCases.enumerated().sorted {
            let left = stats.latest[$0.element.rawValue] ?? .distantPast
            let right = stats.latest[$1.element.rawValue] ?? .distantPast
            return left == right ? $0.offset < $1.offset : left > right
        }.map(\.element)
    }
    private func orderedCustoms(_ stats: SidebarStats) -> [CustomSource] {
        catalog.customs.enumerated().sorted {
            let left = stats.latest["custom:" + $0.element.id.uuidString] ?? .distantPast
            let right = stats.latest["custom:" + $1.element.id.uuidString] ?? .distantPast
            return left == right ? $0.offset < $1.offset : left > right
        }.map(\.element)
    }
    private var rows: [String] {
        let summary = stats
        var ids = ["Tümü", "Sabitlenenler"]
        ids.append(contentsOf: store.collections.map { "collection:" + $0.id.uuidString })
        ids.append(contentsOf: ClipKind.allCases.filter { $0 != .instagram }.map(\.rawValue))
        ids.append(contentsOf: orderedSources(summary).map(\.rawValue))
        ids.append(contentsOf: orderedCustoms(summary).map { "custom:" + $0.id.uuidString })
        return ids
    }
    var body: some View {
        let summary = stats
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 5) {
                    row("Tümü", count: summary.counts["Tümü", default: 0]) { Label(localization.text("Tümü"), systemImage: "square.grid.2x2") }
                    row("Sabitlenenler", count: summary.counts["Sabitlenenler", default: 0]) { Label(localization.text("Sabitlenenler"), systemImage: "pin") }
                    if !store.collections.isEmpty {
                        sectionTitle("KOLEKSİYONLAR")
                        ForEach(store.collections) { collection in
                            row("collection:" + collection.id.uuidString, count: summary.counts["collection:" + collection.id.uuidString, default: 0]) { Label(collection.name, systemImage: "folder") }
                        }
                    }
                    sectionTitle("İÇERİK TÜRLERİ")
                    ForEach(ClipKind.allCases.filter { $0 != .instagram }, id: \.self) { kind in
                        row(kind.rawValue, count: summary.counts[kind.rawValue, default: 0]) { Label(localization.text(kind.rawValue), systemImage: kind.icon) }
                    }
                    sectionTitle("KAYNAKLAR")
                    ForEach(orderedSources(summary), id: \.self) { source in
                        row(source.rawValue, count: summary.counts[source.rawValue, default: 0]) { GroupLabel(kind: nil, source: source) }
                    }
                    if !catalog.customs.isEmpty {
                        sectionTitle("KAYNAKLARIM")
                        ForEach(orderedCustoms(summary)) { source in
                            row("custom:" + source.id.uuidString, count: summary.counts["custom:" + source.id.uuidString, default: 0]) { Label(source.name, systemImage: "globe") }
                        }
                    }
                }.padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 100)
                    .background {
                        GeometryReader { geometry in
                            Color.clear.preference(key: SidebarScrollFrameKey.self, value: geometry.frame(in: .named("sidebar-scroll")))
                        }
                    }
            }
            .coordinateSpace(name: "sidebar-scroll")
            .scrollIndicators(.hidden)
            .onPreferenceChange(SidebarScrollFrameKey.self) { scrollFrame = $0 }
            .overlay(alignment: .trailing) {
                GeometryReader { geometry in
                    let viewport = geometry.size.height
                    let track = max(viewport - 104, 0)
                    let content = scrollFrame.height
                    if content > viewport && viewport > 0 {
                        let thumb = min(track, max(32, track * viewport / content))
                        let progress = min(max(-scrollFrame.minY / (content - viewport), 0), 1)
                        Capsule().fill(.primary.opacity(0.13))
                            .frame(width: 6, height: thumb)
                            .offset(x: geometry.size.width - 9, y: 8 + (track - thumb) * progress)
                    }
                }
                .allowsHitTesting(false).accessibilityHidden(true)
            }
            .onMoveCommand { direction in
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
    private func row<Content: View>(_ id: String, count: Int, @ViewBuilder label: @escaping () -> Content) -> some View {
        GlassSidebarRow(selected: selection == id, count: count, namespace: glassNamespace, action: { select(id) }, label: label)
            .id(id).focused($focusedRow, equals: id)
    }
}

private struct SidebarScrollFrameKey: PreferenceKey {
    static var defaultValue = CGRect.zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct GlassSidebarRow<Content: View>: View {
    let selected: Bool
    let count: Int
    let namespace: Namespace.ID
    let action: () -> Void
    @ViewBuilder let label: () -> Content
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                label().labelStyle(.titleAndIcon).frame(maxWidth: .infinity, alignment: .leading)
                Text(count.formatted()).font(.system(size: 10, weight: .semibold, design: .rounded))
                    .monospacedDigit().foregroundStyle(selected ? Color.accentColor : Color.secondary)
                    .lineLimit(1).minimumScaleFactor(0.6).padding(3).frame(width: 26, height: 26)
                    .background(Circle().fill(selected ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.075)))
            }
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

struct SidebarSettingsFooter: View {
    let title: String
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 36, height: 36)
                    .background(.primary.opacity(hovering ? 0.16 : 0.08), in: Circle())
                Text(title).font(.system(size: 14, weight: .semibold))
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                    .offset(x: hovering && !reduceMotion ? 2 : 0)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(.primary.opacity(hovering ? 0.06 : 0), in: RoundedRectangle(cornerRadius: 14))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12).padding(.bottom, 12).padding(.top, 24)
        .frame(maxWidth: .infinity)
        .background {
            if reduceTransparency {
                Color(nsColor: .windowBackgroundColor)
            } else {
                Rectangle().fill(.regularMaterial)
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.3)], startPoint: .top, endPoint: .bottom))
            }
        }
        .onHover { hovering = $0 }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: hovering)
    }
}
