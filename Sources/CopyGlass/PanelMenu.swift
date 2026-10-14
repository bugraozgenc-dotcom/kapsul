import SwiftUI
import AppKit

struct PanelMenu: View {
    @EnvironmentObject private var updater: AppUpdater
    @EnvironmentObject private var panel: PanelController
    @EnvironmentObject private var store: ClipboardStore
    @EnvironmentObject private var catalog: SourceCatalog
    @EnvironmentObject private var localization: AppLocalization
    @Environment(\.openWindow) private var openWindow
    @AppStorage("appearance") private var appearance = AppearanceMode.system.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var selection = "Tümü"
    private var filteredClips: [Clip] { store.clips.filter { matches($0, group: selection) } }
    private var pinnedClips: [Clip] { filteredClips.filter(\.pinned) }
    private var recentClips: [Clip] {
        let clips = filteredClips.filter { !$0.pinned }
        return selection == "Tümü" ? Array(clips.prefix(8)) : clips
    }
    private var selectedTitle: String {
        if let collection = store.collections.first(where: { "collection:" + $0.id.uuidString == selection }) { return collection.name }
        if let custom = catalog.customs.first(where: { "custom:" + $0.id.uuidString == selection }) { return custom.name }
        return localization.text(selection)
    }
    private var groupIDs: [String] {
        ["Tümü", "Sabitlenenler"] + ClipKind.allCases.filter { $0 != .instagram }.map(\.rawValue)
            + ClipSource.allCases.map(\.rawValue)
            + store.collections.map { "collection:" + $0.id.uuidString }
            + catalog.customs.map { "custom:" + $0.id.uuidString }
    }
    private var listHeight: CGFloat {
        min(330, CGFloat(pinnedClips.count + recentClips.count) * 66 + (pinnedClips.isEmpty ? 0 : 56))
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Button {
                        panel.showPanel = { openWindow(id: "history") }
                        panel.open()
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.grid.2x2")
                            Text(localization.text("Geçmiş panelini aç")).fontWeight(.semibold)
                            Spacer()
                            Text("⌘O").font(.system(size: 11, weight: .medium)).opacity(0.75)
                        }.font(.system(size: 12)).padding(.horizontal, 14).frame(height: 40)
                    }
                    .buttonStyle(MenuSurfaceButtonStyle(prominent: true))
                    .keyboardShortcut("o", modifiers: .command)
                    Button { store.paused.toggle() } label: {
                        Image(systemName: store.paused ? "play.fill" : "pause.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(MenuSurfaceButtonStyle())
                    .help(localization.text(store.paused ? "Takibi sürdür" : "Takibi duraklat"))
                    .accessibilityLabel(localization.text(store.paused ? "Takibi sürdür" : "Takibi duraklat"))
                }
                if store.paused {
                    Text(localization.text("Takip duraklatıldı"))
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(.orange)
                }
            }.padding(.horizontal, 20).padding(.vertical, 16)

            groupSelector.padding(.bottom, 14)
            Divider().padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(selection == "Tümü" ? localization.text("Son kayıtlar") : selectedTitle)
                        .font(.system(size: 12, weight: .semibold)).lineLimit(1)
                    Spacer()
                    Text(String(filteredClips.count))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .monospacedDigit().foregroundStyle(.secondary)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(.primary.opacity(0.05), in: Capsule())
                }.padding(.horizontal, 8)
                if filteredClips.isEmpty {
                    VStack(spacing: 9) {
                        Image(systemName: "doc.on.clipboard").font(.system(size: 25)).foregroundStyle(.tertiary)
                        Text(localization.text(selection == "Tümü" ? "Henüz kayıt yok" : "Bu grupta henüz kayıt yok"))
                            .font(.system(size: 13, weight: .medium))
                        Text(localization.text(selection == "Tümü" ? "Kopyaladığınız içerikler burada görünür." : "Diğer kayıtlar için başka bir grup seçin."))
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }.frame(maxWidth: .infinity).padding(.vertical, 28)
                } else {
                    ScrollView {
                        VStack(spacing: 4) {
                            if !pinnedClips.isEmpty {
                                if selection != "Sabitlenenler" { listHeading("Sabitlenenler", icon: "pin.fill") }
                                ForEach(pinnedClips) { clip in MenuClipRow(clip: clip) }
                                if !recentClips.isEmpty {
                                    listHeading("Son kayıtlar", icon: "clock")
                                }
                            }
                            ForEach(recentClips) { clip in
                                MenuClipRow(clip: clip)
                            }
                        }
                    }.frame(height: listHeight)
                }
            }.padding(.horizontal, 12).padding(.vertical, 16)

            Divider().padding(.horizontal, 20)
            HStack(spacing: 8) {
                Button { updater.checkForUpdates() } label: {
                    Label(localization.text("Güncellemeleri kontrol et"), systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 9).frame(height: 30)
                }.disabled(!updater.canCheckForUpdates)
                Spacer(minLength: 0)
                Button { NSApplication.shared.terminate(nil) } label: {
                    Image(systemName: "power").font(.system(size: 12)).frame(width: 30, height: 30)
                }
                .help(localization.text("Çıkış"))
                .accessibilityLabel(localization.text("Çıkış"))
            }.buttonStyle(MenuSurfaceButtonStyle()).padding(12)
        }
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared || reduceMotion ? 1 : 0.96, anchor: .top)
        .offset(y: appeared || reduceMotion ? 0 : -8)
        .frame(width: 360)
        .background {
            GlassWindowSurface()
                .overlay(alignment: .top) {
                    LinearGradient(colors: [.blue.opacity(0.08), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .frame(height: 150).allowsHitTesting(false)
                }
        }
        .preferredColorScheme(AppearanceMode(rawValue: appearance)?.colorScheme)
        .onChange(of: groupIDs) { _, ids in
            if !ids.contains(selection) { selection = "Tümü" }
        }
        .task {
            // Allow the initial frame to render before revealing the panel contents.
            do { try await Task.sleep(for: .milliseconds(30)) } catch { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .spring(duration: 0.32, bounce: 0.12)) {
                appeared = true
            }
        }
        .onDisappear {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { appeared = false }
        }
    }

    private func matches(_ clip: Clip, group: String) -> Bool {
        if group == "Tümü" { return true }
        if group == "Sabitlenenler" { return clip.pinned }
        if group.hasPrefix("collection:") {
            return (clip.collectionIDs ?? []).contains { "collection:" + $0.uuidString == group }
        }
        let custom = catalog.customSource(for: clip.value)
        if group.hasPrefix("custom:") { return custom.map { "custom:" + $0.id.uuidString == group } ?? false }
        return clip.kind.rawValue == group || (custom == nil && clip.groupSource?.rawValue == group)
    }

    private var groupSelector: some View {
        VStack(alignment: .leading, spacing: 9) {
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    groupChip("Tümü", title: localization.text("Tümü"), icon: "square.grid.2x2")
                    groupChip("Sabitlenenler", title: localization.text("Sabitlenenler"), icon: "pin.fill")
                    ForEach(ClipKind.allCases.filter { $0 != .instagram }, id: \.self) { kind in
                        groupChip(kind.rawValue, title: localization.text(kind.rawValue), icon: kind.icon)
                    }
                }.padding(.horizontal, 20)
            }.scrollIndicators(.hidden)
            Text(localization.text("KAYNAKLAR")).font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary).padding(.horizontal, 20)
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(ClipSource.allCases, id: \.self) { source in
                        groupChip(source.rawValue, title: source.rawValue, icon: "globe", source: source)
                    }
                    ForEach(catalog.customs) { custom in
                        groupChip("custom:" + custom.id.uuidString, title: custom.name, icon: "globe")
                    }
                }.padding(.horizontal, 20)
            }.scrollIndicators(.hidden)
            if !store.collections.isEmpty {
                Text(localization.text("KOLEKSİYONLAR")).font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary).padding(.horizontal, 20)
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(store.collections) { collection in
                            groupChip("collection:" + collection.id.uuidString, title: collection.name, icon: "folder")
                        }
                    }.padding(.horizontal, 20)
                }.scrollIndicators(.hidden)
            }
        }
    }

    private func groupChip(_ id: String, title: String, icon: String, source: ClipSource? = nil) -> some View {
        let selected = selection == id
        let count = store.clips.filter { matches($0, group: id) }.count
        return Button { selection = id } label: {
            HStack(spacing: 5) {
                if let source { GroupLabel(kind: nil, source: source) }
                else { Label(title, systemImage: icon) }
                Text(String(count)).font(.system(size: 9, weight: .semibold, design: .rounded))
                    .monospacedDigit().foregroundStyle(.secondary)
            }
            .font(.system(size: 11, weight: selected ? .semibold : .medium))
            .lineLimit(1).fixedSize()
            .padding(.horizontal, 10).frame(height: 30)
            .background(selected ? Color.blue.opacity(0.14) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color.blue.opacity(0.3) : .clear, lineWidth: 1))
        }
        .buttonStyle(MenuSurfaceButtonStyle())
        .accessibilityLabel(title + ": " + String(count))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func listHeading(_ title: String, icon: String) -> some View {
        Label(localization.text(title), systemImage: icon)
            .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8).padding(.vertical, 6)
    }
}

private struct MenuClipRow: View {
    let clip: Clip
    @EnvironmentObject private var store: ClipboardStore
    @EnvironmentObject private var localization: AppLocalization
    @State private var copied = false
    @State private var resetTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 0) {
        Button {
            guard store.copy(clip) else { return }
            resetTask?.cancel()
            copied = true
            resetTask = Task { @MainActor in
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
                copied = false
            }
        } label: {
            HStack(spacing: 11) {
                Image(systemName: clip.kind.icon)
                    .font(.system(size: 15, weight: .medium)).foregroundStyle(clip.kind.color)
                    .frame(width: 36, height: 36)
                    .background(clip.kind.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 5) {
                    Text(clip.title.replacingOccurrences(of: "\n", with: " "))
                        .font(.system(size: 12, weight: .medium)).lineLimit(1)
                    HStack(spacing: 5) {
                        Text(localization.text(clip.kind.rawValue))
                        if let source = clip.sourceAppName {
                            Text("·")
                            Text(source).lineLimit(1)
                        }
                    }.font(.system(size: 10)).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                    .font(.system(size: 12))
                    .foregroundStyle(copied ? Color.green : Color.secondary)
            }.padding(.horizontal, 8).frame(height: 62).contentShape(Rectangle())
        }
        .buttonStyle(MenuSurfaceButtonStyle())
        .help(localization.text(copied ? "Kopyalandı" : "Panoya kopyala"))
        .accessibilityLabel(localization.text(copied ? "Kopyalandı" : "Kopyala") + ": " + clip.title)
        Button { store.togglePin(clip) } label: {
            Image(systemName: clip.pinned ? "pin.fill" : "pin")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(clip.pinned ? Color.blue : Color.secondary)
                .frame(width: 30, height: 36)
        }
        .buttonStyle(MenuSurfaceButtonStyle())
        .help(localization.text(clip.pinned ? "Sabitlemeyi kaldır" : "Sabitle"))
        .accessibilityLabel(localization.text(clip.pinned ? "Sabitlemeyi kaldır" : "Sabitle") + ": " + clip.title)
        .accessibilityValue(localization.text(clip.pinned ? "Sabitlenenler" : "Son kayıtlar"))
        }
        .onDisappear { resetTask?.cancel(); copied = false }
    }
}

private struct MenuSurfaceButtonStyle: ButtonStyle {
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        Surface(configuration: configuration, prominent: prominent)
    }
    private struct Surface: View {
        let configuration: ButtonStyle.Configuration
        let prominent: Bool
        @Environment(\.isEnabled) private var enabled
        @State private var hovered = false
        var body: some View {
            configuration.label
                .foregroundStyle(prominent ? Color.white : Color.primary)
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(prominent ? Color.blue.opacity(configuration.isPressed ? 0.75 : (hovered ? 0.9 : 1)) : Color.primary.opacity(configuration.isPressed ? 0.10 : (hovered ? 0.06 : 0)))
                }
                .opacity(enabled ? 1 : 0.4)
                .onHover { hovered = $0 }
        }
    }
}
