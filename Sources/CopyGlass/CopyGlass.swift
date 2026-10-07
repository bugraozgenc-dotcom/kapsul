import SwiftUI
import AppKit
import LinkPresentation

 enum ClipKind: String, Codable, CaseIterable {
    case text = "Metin", url = "Bağlantı", instagram = "Instagram", image = "Görsel", screenshot = "Ekran görüntüsü", file = "Dosya"
    var icon: String { switch self { case .text: return "text.alignleft"; case .url: return "link"; case .instagram: return "camera"; case .image: return "photo"; case .screenshot: return "viewfinder"; case .file: return "doc" } }
    var color: Color { switch self { case .text: return .purple; case .url: return .blue; case .instagram: return .pink; case .image: return .orange; case .screenshot: return .teal; case .file: return .green } }
 }
 enum Retention: String, Codable, CaseIterable {
    case month = "1 ay", quarter = "3 ay", year = "1 yıl", forever = "Sonsuz"
    var months: Int? { switch self { case .month: return 1; case .quarter: return 3; case .year: return 12; case .forever: return nil } }
 }
 struct Clip: Identifiable, Codable {
    var id = UUID()
    var kind: ClipKind
    var value: String
    var date = Date()
    var pinned = false
    var asset: String? = nil
    var source: ClipSource? = nil
    var groupSource: ClipSource? { source ?? ClipSource.fromURL(value) ?? (kind == .instagram ? .instagram : nil) }
    var webURL: URL? { guard let url = URL(string: value), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { return nil }; return url }
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "dd.MM.yyyy • HH:mm"
        return formatter
    }()
    var timestamp: String { Self.timestampFormatter.string(from: date) }
    var title: String {
        if kind == .screenshot { return L10n.text("Ekran görüntüsü") }; if kind == .image { return L10n.text("Kopyalanan görsel") }
        if kind == .file { return URL(fileURLWithPath: value).lastPathComponent }
        if kind == .instagram, let url = URL(string: value) { return url.path.isEmpty ? "Instagram" : url.path }
        if kind == .url { return URL(string: value)?.host ?? value }
        return String(value.prefix(90))
    }
 }
 @MainActor final class ClipboardStore: ObservableObject {
    @Published var clips: [Clip] = []
    @Published var paused = false
    @Published var retention: Retention { didSet { UserDefaults.standard.set(retention.rawValue, forKey: "retention"); prune(); save() } }
    @Published var error: String?
    private var timer: Timer?
    private var screenshotMonitor: ScreenshotMonitor?
    private var count = NSPasteboard.general.changeCount
    private let folder: URL
    init() {
        retention = Retention(rawValue: UserDefaults.standard.string(forKey: "retention") ?? "1 ay") ?? .month
        folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("CopyGlass", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let location = folder.appendingPathComponent("history.json")
            if FileManager.default.fileExists(atPath: location.path) { clips = try JSONDecoder().decode([Clip].self, from: Data(contentsOf: location)) }
        } catch { self.error = L10n.text("Geçmiş yüklenemedi: %@", error.localizedDescription) }
        prune()
        screenshotMonitor = ScreenshotMonitor()
        screenshotMonitor?.onScreenshot = { [weak self] url in
            guard let self else { return false }
            if self.paused { return true }
            return self.importScreenshot(url)
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { [weak self] _ in Task { @MainActor in self?.poll() } }
    }
    @discardableResult func importScreenshot(_ url: URL) -> Bool {
        guard let image = NSImage(contentsOf: url), let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff), let data = rep.representation(using: .png, properties: [:]) else { return false }
        let name = UUID().uuidString + ".png"
        do {
            try data.write(to: folder.appendingPathComponent(name), options: .atomic)
            add(Clip(kind: .screenshot, value: url.lastPathComponent, asset: name))
            return true
        } catch { self.error = L10n.text("Ekran görüntüsü kaydedilemedi: %@", error.localizedDescription); return false }
    }
    func assetURL(_ clip: Clip) -> URL? { clip.asset.map { folder.appendingPathComponent($0) } }
    func poll() {
        prune()
        let board = NSPasteboard.general
        guard board.changeCount != count else { return }
        count = board.changeCount
        guard !paused else { return }
        // Password managers use these standard pasteboard markers for private content.
        let privateTypes = ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType", "org.nspasteboard.AutoGeneratedType"]
        guard !privateTypes.contains(where: { board.types?.contains(NSPasteboard.PasteboardType($0)) == true }) else { return }
        if let files = board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !files.isEmpty {
            for file in files { add(Clip(kind: .file, value: file.path, source: currentSource())) }; return
        }
        if let data = board.data(forType: .png) ?? board.data(forType: .tiff), let image = NSImage(data: data), let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
            let name = UUID().uuidString + ".png"
            do { try png.write(to: folder.appendingPathComponent(name), options: .atomic); add(Clip(kind: .image, value: "Görsel", asset: name, source: currentSource())) } catch { self.error = L10n.text("Görsel kaydedilemedi: %@", error.localizedDescription) }
            return
        }
        guard let value = board.string(forType: .string), !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        var kind: ClipKind = .text
        if let url = URL(string: trimmed), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), let host = url.host?.lowercased() {
            kind = (host == "instagram.com" || host.hasSuffix(".instagram.com")) ? .instagram : .url
        }
        add(Clip(kind: kind, value: kind == .text ? value : trimmed, source: ClipSource.fromURL(trimmed) ?? currentSource()))
    }
    func currentSource() -> ClipSource? { ClipSource.fromBundle(NSWorkspace.shared.frontmostApplication?.bundleIdentifier) }
    func add(_ clip: Clip) {
        if ![.image, .screenshot].contains(clip.kind), let i = clips.firstIndex(where: { $0.value == clip.value && $0.kind == clip.kind && $0.groupSource == clip.groupSource }) { var existing = clips.remove(at: i); existing.date = Date(); clips.insert(existing, at: 0) }
        else { clips.insert(clip, at: 0) }
        save()
    }
    @discardableResult func copy(_ clip: Clip) -> Bool {
        let board = NSPasteboard.general
        let success: Bool
        if [.image, .screenshot].contains(clip.kind) {
            guard let url = assetURL(clip), let image = NSImage(contentsOf: url) else {
                error = L10n.text("Kopyalanacak görsel bulunamadı.")
                return false
            }
            board.clearContents()
            success = board.writeObjects([image])
        } else if clip.kind == .file {
            board.clearContents()
            success = board.writeObjects([NSURL(fileURLWithPath: clip.value)])
        } else {
            board.clearContents()
            success = board.setString(clip.value, forType: .string)
        }
        count = board.changeCount
        if !success { error = L10n.text("İçerik panoya kopyalanamadı.") }
        return success
    }
    func togglePin(_ clip: Clip) { guard let i = clips.firstIndex(where: { $0.id == clip.id }) else { return }; clips[i].pinned.toggle(); save() }
    func remove(_ clip: Clip) { if let url = assetURL(clip) { try? FileManager.default.removeItem(at: url) }; clips.removeAll { $0.id == clip.id }; save() }
    func clear() { for clip in clips { if let url = assetURL(clip) { try? FileManager.default.removeItem(at: url) } }; clips = []; save() }
    func prune() {
        guard let months = retention.months, let cutoff = Calendar.current.date(byAdding: .month, value: -months, to: Date()) else { return }
        let expired = clips.filter { $0.date < cutoff }
        guard !expired.isEmpty else { return }
        for clip in expired { if let url = assetURL(clip) { try? FileManager.default.removeItem(at: url) } }
        clips.removeAll { $0.date < cutoff }; save()
    }
    func save() { do { try JSONEncoder().encode(clips).write(to: folder.appendingPathComponent("history.json"), options: .atomic) } catch { self.error = L10n.text("Geçmiş kaydedilemedi: %@", error.localizedDescription) } }
 }

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
    @EnvironmentObject var store: ClipboardStore
    @EnvironmentObject var catalog: SourceCatalog
    @EnvironmentObject private var localization: AppLocalization
    @AppStorage("linkPreviews") var previews = false
    @State private var confirmDelete = false
    @State private var deleteHovered = false
    private let contentHeight: CGFloat = 177
    private var header: some View {
        HStack {
            Group {
                if let custom = catalog.customSource(for: clip.value) { Label(custom.name, systemImage: "globe").foregroundStyle(.blue) }
                else { GroupLabel(kind: clip.kind, source: clip.groupSource).foregroundStyle(clip.kind.color) }
            }.font(.caption.weight(.semibold)).lineLimit(1)
            Spacer()
            if clip.webURL != nil { Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.secondary) }
            if clip.pinned { Image(systemName: "pin.fill").foregroundStyle(.secondary) }
        }.padding(.trailing, 30).frame(height: 20)
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
                CopyFeedbackButton { store.copy(clip) }
            }.frame(height: 28)

        }.padding(18).frame(maxWidth: .infinity).frame(height: 304, alignment: .top)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.3), lineWidth: 1))
        .overlay(alignment: .topTrailing) {
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
        .alert(localization.text("Emin misiniz?"), isPresented: $confirmDelete) {
            Button(localization.text("Vazgeç"), role: .cancel) {}
            Button(localization.text("Sil"), role: .destructive) { store.remove(clip) }
        } message: {
            Text(localization.text("Bu kaydı silmek istediğinize emin misiniz? Kayıt pano geçmişinden kaldırılacak."))
        }
        .contextMenu { Button(localization.text("Kopyala")) { store.copy(clip) }; Button(localization.text(clip.pinned ? "Sabitlemeyi kaldır" : "Sabitle")) { store.togglePin(clip) }; if let url = clip.webURL { Button(localization.text("Tarayıcıda aç")) { NSWorkspace.shared.open(url) } }; Button(localization.text("Sil"), role: .destructive) { confirmDelete = true } }
    }
 }

 struct ContentView: View {
    @EnvironmentObject var store: ClipboardStore
    @EnvironmentObject var catalog: SourceCatalog
    @EnvironmentObject private var localization: AppLocalization
    @AppStorage("appearance") private var appearance = AppearanceMode.system.rawValue
    @State private var selection = "Tümü"
    @State private var query = ""
    @State private var settings = false
    @FocusState private var searchFocused: Bool
    private var selectedTitle: String {
        if selection == "Tümü" { return localization.text("Her şey, bir arada.") }
        if selection.hasPrefix("custom:"), let source = catalog.customs.first(where: { "custom:" + $0.id.uuidString == selection }) { return source.name }
        return localization.text(selection)
    }
    var filtered: [Clip] {
        store.clips.filter { clip in
            let custom = catalog.customSource(for: clip.value)
            let matchesGroup: Bool
            if selection == "Tümü" { matchesGroup = true }
            else if selection == "Sabitlenenler" { matchesGroup = clip.pinned }
            else if selection.hasPrefix("custom:") { matchesGroup = custom.map { "custom:" + $0.id.uuidString == selection } ?? false }
            else { matchesGroup = clip.kind.rawValue == selection || (custom == nil && clip.groupSource?.rawValue == selection) }
            return matchesGroup && (query.isEmpty || clip.value.localizedCaseInsensitiveContains(query))
        }
    }
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 24) {
                BrandHeader().padding(.top, 22).padding(.horizontal, 18)
                GlassSidebar(selection: $selection)
                VStack(alignment: .leading, spacing: 12) {
                    Button { settings = true } label: { Label(localization.text("Ayarlar"), systemImage: "gearshape") }.buttonStyle(.plain)
                }.padding(20)
            }.background(.ultraThinMaterial).navigationSplitViewColumnWidth(220)
        } detail: {
            ZStack {
                LinearGradient(colors: [Color.blue.opacity(0.12), Color.purple.opacity(0.07), Color(nsColor: .windowBackgroundColor)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
                VStack(alignment: .leading, spacing: 22) {
                    HStack { VStack(alignment: .leading, spacing: 5) { Text(selectedTitle).font(.system(size: 30, weight: .bold, design: .rounded)) }; Spacer(); Button { store.paused.toggle() } label: { Image(systemName: store.paused ? "play" : "pause") }.help(localization.text(store.paused ? "Takibi sürdür" : "Takibi duraklat")) }
                    HStack { Image(systemName: "magnifyingglass").foregroundStyle(.secondary); TextField(localization.text("Metin veya bağlantı ara…"), text: $query).textFieldStyle(.plain).focused($searchFocused); if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain) } }.padding(13).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    if filtered.isEmpty {
                        if query.isEmpty { ClipboardEmptyState() }
                        else { ContentUnavailableView(localization.text("Sonuç bulunamadı"), systemImage: "magnifyingglass", description: Text(localization.text("Başka bir kelime dene."))).frame(maxWidth: .infinity, maxHeight: .infinity) }
                    }
                    else { ScrollView { LazyVGrid(columns: [GridItem(.adaptive(minimum: 260, maximum: 400), alignment: .top)], alignment: .leading, spacing: 18) { ForEach(filtered) { ClipCard(clip: $0) } }.padding(.bottom, 20) } }
                    HStack { Text(localization.text("Yerel depolama")).font(.caption); Spacer(); Text(localization.text("Saklama: %@", localization.text(store.retention.rawValue))).font(.caption) }.foregroundStyle(.secondary)
                }.padding(30)
            }
        }.preferredColorScheme(AppearanceMode(rawValue: appearance)?.colorScheme)
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
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject var store: ClipboardStore
    @EnvironmentObject private var localization: AppLocalization
    var body: some View {
        Button(localization.text("Geçmiş panelini aç")) {
            openWindow(id: "history")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }.keyboardShortcut("o", modifiers: .command)
        Divider()
        Button(localization.text(store.paused ? "Takibi sürdür" : "Takibi duraklat")) { store.paused.toggle() }
        Divider()
        ForEach(Array(store.clips.prefix(8))) { clip in Button(clip.title) { store.copy(clip) } }
        Divider()
        Button(localization.text("Çıkış")) { NSApplication.shared.terminate(nil) }
    }
 }
 @main struct KapsulApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ClipboardStore()
    @StateObject private var catalog = SourceCatalog()
    @StateObject private var localization = AppLocalization()
    var body: some Scene {
        Window(localization.text("Kapsül — Pano geçmişi"), id: "history") { ContentView().environmentObject(store).environmentObject(catalog).environmentObject(localization).environment(\.locale, localization.language.locale) }
            .windowStyle(.hiddenTitleBar)
            .defaultSize(width: 1100, height: 740)
        MenuBarExtra("Kapsül", systemImage: "doc.on.clipboard") {
            PanelMenu().environmentObject(store).environmentObject(localization).environment(\.locale, localization.language.locale)
        }
    }
 }
