import SwiftUI
import AppKit
import LinkPresentation


 struct GroupLabel: View {
    var kind: ClipKind?
    var source: ClipSource?
    @EnvironmentObject private var localization: AppLocalization
    var brandColor: Color {
        guard let source else { return .secondary }
        let hex = source.colorHex
        if hex == 0 { return .primary }
        return Color(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
    var body: some View {
        if let source, let url = Bundle.module.url(forResource: source.assetName, withExtension: "png"), let image = NSImage(contentsOf: url) {
            Label { Text(source.rawValue) } icon: { Image(nsImage: image).resizable().renderingMode(.template).scaledToFit().frame(width: 17, height: 17).foregroundStyle(brandColor) }
        } else if let kind { Label(localization.text(kind.rawValue), systemImage: kind.icon) }
    }
 }

 struct ClipCard: View {
    let clip: Clip
    var selectionMode = false
    var selected = false
    var onSelection: () -> Void = {}
    @EnvironmentObject var store: ClipboardStore
    @EnvironmentObject var catalog: SourceCatalog
    @EnvironmentObject private var localization: AppLocalization
    @AppStorage("linkPreviews") var previews = false
    @State private var confirmDelete = false
    @State private var deleteHovered = false
    @State private var editMetadata = false
    @State private var showRecognizedText = false
    private let contentHeight: CGFloat = 177
    private var header: some View {
        HStack {
            Group {
                if let custom = catalog.customSource(for: clip.value) { Label(custom.name, systemImage: "globe").foregroundStyle(.blue) }
                else { GroupLabel(kind: clip.kind, source: clip.groupSource).foregroundStyle(clip.kind.color) }
            }.font(.caption.weight(.semibold)).lineLimit(1)
            Spacer()
            if clip.webURL != nil { Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.secondary) }
            if !(clip.tags ?? []).isEmpty { Image(systemName: "tag.fill").foregroundStyle(.secondary).help((clip.tags ?? []).joined(separator: ", ")) }
            if clip.pinned { Image(systemName: "pin.fill").foregroundStyle(.secondary) }
        }.padding(.leading, selectionMode ? 30 : 0).padding(.trailing, 30).frame(height: 20)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let url = clip.webURL {
                Link(destination: url) {
                    VStack(alignment: .leading, spacing: 14) {
                        header
                        Group {
                            if previews { LinkPreview(url: url) }
                            else { Text(clip.value).font(.system(size: 14, weight: .medium)).lineLimit(8) }
                        }.frame(maxWidth: .infinity, minHeight: contentHeight, maxHeight: contentHeight, alignment: .topLeading)
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .help(localization.text("Varsayılan tarayıcıda aç"))
                    .accessibilityLabel(localization.text("Tarayıcıda aç: %@", clip.title))
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    Group {
                        if [.image, .screenshot].contains(clip.kind), let url = store.assetURL(clip), let image = NSImage(contentsOf: url) {
                            ImagePreview(image: image, title: clip.title, thumbnailHeight: contentHeight) { store.copy(clip) }
                        } else {
                            Text(clip.value).font(.system(size: 15)).lineLimit(8).textSelection(.enabled)
                        }
                    }.frame(maxWidth: .infinity, minHeight: contentHeight, maxHeight: contentHeight, alignment: .topLeading)
                }
            }
            Divider().frame(height: 1).opacity(0.5)
            HStack(spacing: 4) {
                Text(clip.timestamp).font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }.frame(height: 18)
            HStack {
                Menu { cardActions } label: { Image(systemName: "ellipsis.circle") }.menuStyle(.borderlessButton).fixedSize()
                    .help(localization.text("Kayıt işlemleri"))
                if [.image, .screenshot].contains(clip.kind) {
                    Button { openRecognizedText() } label: {
                        if store.recognizing.contains(clip.id) { ProgressView().controlSize(.small) }
                        else { Image(systemName: "text.viewfinder") }
                    }.buttonStyle(.plain).help(localization.text("Görselden metin"))
                }
                Spacer()
                CopyFeedbackButton { store.copy(clip) }
            }.frame(height: 28)

        }.padding(18).frame(maxWidth: .infinity).frame(height: 334, alignment: .top)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.3), lineWidth: 1))
        .allowsHitTesting(!selectionMode).accessibilityHidden(selectionMode)
        .overlay(alignment: .topTrailing) {
            if !selectionMode {
            Button { confirmDelete = true } label: {
                Image(systemName: "xmark").font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(deleteHovered ? Color.red : Color.secondary)
                    .frame(width: 26, height: 26)
                    .background(.thinMaterial, in: Circle())
                    .overlay(Circle().stroke(.primary.opacity(0.08), lineWidth: 0.5))
                    .contentShape(Circle())
            }.buttonStyle(.plain).padding(12)
                .onHover { deleteHovered = $0 }
                .help(localization.text("Kaydı sil"))
                .accessibilityLabel(localization.text("Kaydı sil: %@", clip.title))
            }
        }
        .overlay {
            if selectionMode {
                Button(action: onSelection) {
                    RoundedRectangle(cornerRadius: 20).fill(Color.blue.opacity(selected ? 0.10 : 0.001))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(selected ? Color.blue : Color.primary.opacity(0.12), lineWidth: selected ? 2 : 1))
                        .contentShape(RoundedRectangle(cornerRadius: 20))
                }.buttonStyle(.plain)
                    .accessibilityLabel(localization.text("Seç: %@", clip.title))
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
        .overlay(alignment: .topLeading) {
            if selectionMode {
                selectionMark.padding(14).allowsHitTesting(false).accessibilityHidden(true)
            }
        }
        .sheet(isPresented: $editMetadata) { ClipMetadataEditor(clip: clip) }
        .sheet(isPresented: $showRecognizedText) { RecognizedTextView(clipID: clip.id) }
        .alert(localization.text("Emin misiniz?"), isPresented: $confirmDelete) {
            Button(localization.text("Vazgeç"), role: .cancel) {}
            Button(localization.text("Sil"), role: .destructive) { store.remove(clip) }
        } message: {
            Text(localization.text("Bu kaydı silmek istediğinize emin misiniz? Kayıt pano geçmişinden kaldırılacak."))
        }
        .contextMenu { if !selectionMode { cardActions } }
    }
    private var selectionMark: some View {
        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(selected ? Color.blue : Color.secondary)
            .frame(width: 28, height: 28)
            .background(.regularMaterial, in: Circle())
    }
    @ViewBuilder private var cardActions: some View {
        Button(localization.text("Kopyala")) { store.copy(clip) }
        Button(localization.text("Düz metin olarak kopyala")) { store.copy(clip, plainText: true) }
            .disabled([.image, .screenshot].contains(clip.kind) && (clip.extractedText ?? "").isEmpty)
        if [.image, .screenshot].contains(clip.kind) { Button(localization.text("Görselden metin")) { openRecognizedText() } }
        Divider()
        Button(localization.text("Etiketler ve koleksiyonlar")) { editMetadata = true }
        Button(localization.text(clip.pinned ? "Sabitlemeyi kaldır" : "Sabitle")) { store.togglePin(clip) }
        if let url = clip.webURL { Button(localization.text("Tarayıcıda aç")) { NSWorkspace.shared.open(url) } }
        if let id = clip.sourceBundleID, !store.isExcluded(id) {
            Button(localization.text("Bu uygulamayı hariç tut")) { store.excludedApps.append(ExcludedApplication(id: id, name: clip.sourceAppName ?? id)) }
        }
        Divider()
        Button(localization.text("Sil"), role: .destructive) { confirmDelete = true }
    }
    private func openRecognizedText() {
        if clip.extractedText == nil { store.recognize(clip) }
        showRecognizedText = true
    }
 }

 struct ContentView: View {
    @EnvironmentObject var store: ClipboardStore
    @EnvironmentObject var catalog: SourceCatalog
    @EnvironmentObject private var localization: AppLocalization
    @AppStorage("appearance") private var appearance = AppearanceMode.system.rawValue
    @Environment(\.colorScheme) private var colorScheme
    @State private var selection = "Tümü"
    @State private var query = ""
    @State private var settings = false
    @State private var selecting = false
    @State private var selectedIDs = Set<UUID>()
    @EnvironmentObject private var panel: PanelController
    @Environment(\.openWindow) private var openWindow
    @FocusState private var searchFocused: Bool
    private var selectedTitle: String {
        if selection == "Tümü" { return localization.text("Tümü") }
        if selection.hasPrefix("collection:"), let collection = store.collections.first(where: { "collection:" + $0.id.uuidString == selection }) { return collection.name }
        if selection.hasPrefix("custom:"), let source = catalog.customs.first(where: { "custom:" + $0.id.uuidString == selection }) { return source.name }
        return localization.text(selection)
    }
    var filtered: [Clip] {
        store.clips.filter { clip in
            let custom = catalog.customSource(for: clip.value)
            let matchesGroup: Bool
            if selection == "Tümü" { matchesGroup = true }
            else if selection == "Sabitlenenler" { matchesGroup = clip.pinned }
            else if selection.hasPrefix("collection:") { matchesGroup = (clip.collectionIDs ?? []).contains { "collection:" + $0.uuidString == selection } }
            else if selection.hasPrefix("custom:") { matchesGroup = custom.map { "custom:" + $0.id.uuidString == selection } ?? false }
            else { matchesGroup = clip.kind.rawValue == selection || (custom == nil && clip.groupSource?.rawValue == selection) }
            return matchesGroup && (query.isEmpty || clip.searchableText.localizedCaseInsensitiveContains(query))
        }
    }
    var body: some View {
        NavigationSplitView { sidebar } detail: { detailPanel }
            .background { GlassWindowSurface().ignoresSafeArea() }
            .preferredColorScheme(AppearanceMode(rawValue: appearance)?.colorScheme)
            .onAppear {
                panel.showPanel = { openWindow(id: "history") }
                panel.start()
            }
            .onChange(of: selecting) { _, active in if active { searchFocused = false } }
            .onChange(of: filtered.map(\.id)) { _, ids in selectedIDs.formIntersection(ids) }
            .onChange(of: store.collections) { _, collections in
                if selection.hasPrefix("collection:"), !collections.contains(where: { "collection:" + $0.id.uuidString == selection }) { selection = "Tümü" }
            }
            .onChange(of: localization.language) { _, _ in
                let titleKey = "Kapsül — Pano geçmişi"
                let knownTitles = Set(L10n.catalog.values.compactMap { $0[titleKey] })
                for window in NSApplication.shared.windows where knownTitles.contains(window.title) {
                    window.title = localization.text(titleKey)
                }
            }
            .onChange(of: catalog.customs) { _, sources in
                if selection.hasPrefix("custom:"), !sources.contains(where: { "custom:" + $0.id.uuidString == selection }) { selection = "Tümü" }
            }.frame(minWidth: 850, minHeight: 600).background { Button(localization.text("Ara")) { searchFocused = true }.keyboardShortcut("f", modifiers: .command).hidden() }.sheet(isPresented: $settings) { SettingsView() }.alert(localization.text("Depolama hatası"), isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button(localization.text("Tamam")) { store.error = nil } } message: { Text(store.error ?? "") }
    }
    private var sidebar: some View {
            VStack(alignment: .leading, spacing: 24) {
                BrandHeader().padding(.top, 22).padding(.horizontal, 18)
                GlassSidebar(selection: $selection)
                    .overlay(alignment: .bottom) {
                        SidebarSettingsFooter(title: localization.text("Ayarlar")) { settings = true }
                    }
            }.background(SidebarTint())
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 360)
    }
    private var detailPanel: some View {
            ZStack {
                LinearGradient(colors: [Color.blue.opacity(0.07), Color.purple.opacity(0.035), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
                VStack(alignment: .leading, spacing: 22) {
                    HStack { VStack(alignment: .leading, spacing: 5) { Text(selectedTitle).font(.system(size: 30, weight: .bold, design: .rounded)) }; Spacer(); Button(localization.text(selecting ? "Seçimi bitir" : "Çoklu seçim")) { selecting.toggle(); selectedIDs = [] }; Button { store.paused.toggle() } label: { Image(systemName: store.paused ? "play" : "pause") }.help(localization.text(store.paused ? "Takibi sürdür" : "Takibi duraklat")) }
                    HStack { Image(systemName: "magnifyingglass").foregroundStyle(.secondary); TextField(localization.text("Metin veya bağlantı ara…"), text: $query).textFieldStyle(.plain).focused($searchFocused); if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain) } }.padding(13).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    if selecting {
                        BulkSelectionBar(ids: $selectedIDs, visibleIDs: Set(filtered.map(\.id))) {
                            selecting = false; selectedIDs = []
                        }
                    }
                    if let notice = store.notice {
                        HStack {
                            Text(notice).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button { store.notice = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
                        }
                    }
                    if filtered.isEmpty {
                        if query.isEmpty { ClipboardEmptyState() }
                        else { ContentUnavailableView(localization.text("Sonuç bulunamadı"), systemImage: "magnifyingglass", description: Text(localization.text("Başka bir kelime dene."))).frame(maxWidth: .infinity, maxHeight: .infinity) }
                    }
                    else { ScrollView { LazyVGrid(columns: [GridItem(.adaptive(minimum: 260, maximum: 400), alignment: .top)], alignment: .leading, spacing: 18) { ForEach(filtered) { clip in ClipCard(clip: clip, selectionMode: selecting, selected: selectedIDs.contains(clip.id), onSelection: {
                        if !selecting { selecting = true; selectedIDs = [] }
                        if selectedIDs.contains(clip.id) { selectedIDs.remove(clip.id) } else { selectedIDs.insert(clip.id) }
                    }) } }.padding(.bottom, 20) } }
                }.padding(30)
            }
    }
 }

 final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let url = Bundle.module.url(forResource: "app-icon", withExtension: "png"), let icon = NSImage(contentsOf: url) {
            NSApplication.shared.applicationIconImage = icon
        }
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { sender.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil) }
        sender.activate(ignoringOtherApps: true)
        return true
    }
 }
 struct PanelMenu: View {
    @EnvironmentObject private var updater: AppUpdater
    @EnvironmentObject private var panel: PanelController
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject var store: ClipboardStore
    @EnvironmentObject private var localization: AppLocalization
    var body: some View {
        Button(localization.text("Geçmiş panelini aç")) {
            panel.showPanel = { openWindow(id: "history") }
            panel.open()
        }.keyboardShortcut("o", modifiers: .command)
        Divider()
        Button(localization.text(store.paused ? "Takibi sürdür" : "Takibi duraklat")) { store.paused.toggle() }
        Divider()
        ForEach(Array(store.clips.prefix(8))) { clip in Button(clip.title) { store.copy(clip) } }
        Divider()
        Button(localization.text("Güncellemeleri kontrol et")) { updater.checkForUpdates() }.disabled(!updater.canCheckForUpdates)
        Divider()
        Button(localization.text("Çıkış")) { NSApplication.shared.terminate(nil) }
    }
 }
 @main struct KapsulApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ClipboardStore()
    @StateObject private var catalog = SourceCatalog()
    @StateObject private var localization = AppLocalization()
    @StateObject private var updater = AppUpdater()
    @StateObject private var panel = PanelController.shared
    var body: some Scene {
        Window(localization.text("Kapsül — Pano geçmişi"), id: "history") { ContentView().environmentObject(panel).environmentObject(updater).environmentObject(store).environmentObject(catalog).environmentObject(localization).environment(\.locale, localization.language.locale) }
            .windowStyle(.hiddenTitleBar)
            .defaultSize(width: 1100, height: 740)
            .commands {
                CommandGroup(after: .appInfo) {
                    Button(localization.text("Güncellemeleri kontrol et")) { updater.checkForUpdates() }
                        .disabled(!updater.canCheckForUpdates)
                }
            }
        MenuBarExtra("Kapsül", systemImage: "doc.on.clipboard") {
            PanelMenu().environmentObject(panel).environmentObject(updater).environmentObject(store).environmentObject(localization).environment(\.locale, localization.language.locale)
        }
    }
 }
