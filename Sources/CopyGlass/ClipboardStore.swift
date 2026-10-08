import AppKit
import Combine
import Foundation
 @MainActor final class ClipboardStore: ObservableObject {
    @Published var clips: [Clip] = []
    @Published var paused = false
    @Published private(set) var collections: [ClipCollection] = []
    @Published private(set) var recognizing = Set<UUID>()
    @Published private(set) var recognitionErrors: [UUID: String] = [:]
    @Published private(set) var transferring = false
    @Published var notice: String?
    @Published var excludedApps: [ExcludedApplication] = [] {
        didSet { if let data = try? JSONEncoder().encode(excludedApps) { defaults.set(data, forKey: "excludedApps") } }
    }
    @Published var retention: Retention { didSet { defaults.set(retention.rawValue, forKey: "retention"); prune(); save() } }
    @Published var error: String?
    private var timer: Timer?
    private var screenshotMonitor: ScreenshotMonitor?
    private var count: Int
    private let board: NSPasteboard
    private let defaults: UserDefaults
    private let frontmostApp: () -> ExcludedApplication?
    private var loadingFailure = false
    private var committedDocument: HistoryDocument?
    private var recognitionTasks: [UUID: Task<Void, Never>] = [:]
    private let folder: URL
    init(folder: URL? = nil, defaults: UserDefaults = .standard, pasteboard: NSPasteboard = .general, monitoring: Bool = true,
         applicationProvider: @escaping () -> ExcludedApplication? = {
             guard let app = NSWorkspace.shared.frontmostApplication, let id = app.bundleIdentifier else { return nil }
             return ExcludedApplication(id: id, name: app.localizedName ?? id)
         }) {
        self.defaults = defaults
        frontmostApp = applicationProvider
        board = pasteboard
        count = pasteboard.changeCount
        retention = Retention(rawValue: defaults.string(forKey: "retention") ?? "1 ay") ?? .month
        self.folder = folder ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("CopyGlass", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: self.folder, withIntermediateDirectories: true)
            let location = self.folder.appendingPathComponent("history.json")
            if FileManager.default.fileExists(atPath: location.path) {
                let data = try Data(contentsOf: location)
                if let document = try? JSONDecoder().decode(HistoryDocument.self, from: data) {
                    guard document.version == 1 else { throw BackupError.invalid }
                    clips = document.clips; collections = document.collections
                } else { clips = try JSONDecoder().decode([Clip].self, from: data) }
            }
        } catch { loadingFailure = true; self.error = L10n.text("Geçmiş yüklenemedi: %@", error.localizedDescription) }
        if let data = defaults.data(forKey: "excludedApps"), let apps = try? JSONDecoder().decode([ExcludedApplication].self, from: data) { excludedApps = apps }
        committedDocument = HistoryDocument(clips: clips, collections: collections)
        prune()
        guard monitoring else { return }
        screenshotMonitor = ScreenshotMonitor()
        screenshotMonitor?.onScreenshot = { [weak self] url in
            guard let self else { return false }
            if self.paused || self.isExcluded(self.frontmostApp()?.id) { return true }
            return self.importScreenshot(url)
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { [weak self] _ in Task { @MainActor in self?.poll() } }
    }
    @discardableResult func importScreenshot(_ url: URL) -> Bool {
        guard !loadingFailure, let image = NSImage(contentsOf: url), let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff), let data = rep.representation(using: .png, properties: [:]) else { return false }
        let name = UUID().uuidString + ".png"
        do {
            try data.write(to: folder.appendingPathComponent(name), options: .atomic)
            add(Clip(kind: .screenshot, value: url.lastPathComponent, asset: name))
            return true
        } catch { self.error = L10n.text("Ekran görüntüsü kaydedilemedi: %@", error.localizedDescription); return false }
    }
    func assetURL(_ clip: Clip) -> URL? {
        guard let name = clip.asset, HistoryBackup.validAssetName(name) else { return nil }
        return folder.appendingPathComponent(name)
    }
    func isExcluded(_ bundleID: String?) -> Bool { bundleID.map { id in excludedApps.contains { $0.id == id } } ?? false }
    func poll() {
        prune()
        guard board.changeCount != count else { return }
        count = board.changeCount
        let application = frontmostApp()
        guard !loadingFailure, !paused, !isExcluded(application?.id) else { return }
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
        var clip = Clip(kind: kind, value: kind == .text ? value : trimmed, source: ClipSource.fromURL(trimmed) ?? currentSource())
        clip.richText = kind == .text ? board.data(forType: .rtf) : nil
        add(clip)
    }
    func currentSource() -> ClipSource? { ClipSource.fromBundle(frontmostApp()?.id) }
    func add(_ incoming: Clip) {
        guard !loadingFailure else { return }
        var clip = incoming
        if let app = frontmostApp(), app.id != Bundle.main.bundleIdentifier {
            clip.sourceBundleID = app.id; clip.sourceAppName = app.name
        }
        if ![.image, .screenshot].contains(clip.kind), let i = clips.firstIndex(where: { $0.value == clip.value && $0.kind == clip.kind && $0.groupSource == clip.groupSource }) { var existing = clips.remove(at: i); existing.date = Date(); existing.richText = clip.richText; clips.insert(existing, at: 0) }
        else { clips.insert(clip, at: 0) }
        guard save() else { return }
        if defaults.object(forKey: "automaticOCR") as? Bool ?? true, [.image, .screenshot].contains(clip.kind) { recognize(clip) }
    }
    @discardableResult func copy(_ clip: Clip, plainText: Bool = false) -> Bool {
        let success: Bool
        if plainText {
            let value = [.image, .screenshot].contains(clip.kind) ? (clip.extractedText ?? "") : clip.value
            guard !value.isEmpty else { error = L10n.text("Bu kayıtta kopyalanacak metin yok."); return false }
            board.clearContents()
            success = board.setString(value, forType: .string)
        } else if [.image, .screenshot].contains(clip.kind) {
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
            var written = board.setString(clip.value, forType: .string)
            if let rtf = clip.richText { written = board.setData(rtf, forType: .rtf) && written }
            success = written
        }
        count = board.changeCount
        if !success { error = L10n.text("İçerik panoya kopyalanamadı.") }
        return success
    }
    func togglePin(_ clip: Clip) { guard let i = clips.firstIndex(where: { $0.id == clip.id }) else { return }; clips[i].pinned.toggle(); save() }
    func remove(_ clip: Clip) { removeMany([clip.id]) }
    func clear() { removeMany(Set(clips.map(\.id))) }
    func prune() {
        guard let months = retention.months, let cutoff = Calendar.current.date(byAdding: .month, value: -months, to: Date()) else { return }
        let expired = Set(clips.filter { $0.date < cutoff }.map(\.id))
        guard !expired.isEmpty else { return }
        removeMany(expired)
    }
    @discardableResult func save() -> Bool {
        guard !loadingFailure else { return false }
        do { try persist(HistoryDocument(clips: clips, collections: collections)); return true } catch {
            if let committedDocument { clips = committedDocument.clips; collections = committedDocument.collections }
            self.error = L10n.text("Geçmiş kaydedilemedi: %@", error.localizedDescription); return false
        }
    }
    private func persist(_ document: HistoryDocument) throws {
        try JSONEncoder().encode(document).write(to: folder.appendingPathComponent("history.json"), options: .atomic)
        committedDocument = document
    }

    @discardableResult func recognize(_ clip: Clip) -> Task<Void, Never>? {
        if let existing = recognitionTasks[clip.id] { return existing }
        guard let url = assetURL(clip) else { return nil }
        recognitionErrors.removeValue(forKey: clip.id)
        recognizing.insert(clip.id)
        let task = Task { [weak self] in
            defer { self?.recognizing.remove(clip.id); self?.recognitionTasks.removeValue(forKey: clip.id) }
            do {
                let text = try await TextRecognition.recognize(url)
                guard !Task.isCancelled, let self, let index = self.clips.firstIndex(where: { $0.id == clip.id }) else { return }
                self.clips[index].extractedText = text
                self.save()
                if text.isEmpty { self.notice = L10n.text("Görselde okunabilir metin bulunamadı.") }
            } catch { if !Task.isCancelled { self?.recognitionErrors[clip.id] = L10n.text("Metin çıkarılamadı: %@", error.localizedDescription) } }
        }
        recognitionTasks[clip.id] = task
        return task
    }

    func updateMetadata(_ clip: Clip, tags: String, collectionIDs: Set<UUID>) {
        guard let index = clips.firstIndex(where: { $0.id == clip.id }) else { return }
        var unique: [String] = []
        for tag in tags.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }).filter({ !$0.isEmpty }) {
            let value = String(tag.prefix(40))
            if !unique.contains(where: { SourceValidation.canonicalName($0) == SourceValidation.canonicalName(value) }) { unique.append(value) }
        }
        clips[index].tags = Array(unique.prefix(50))
        clips[index].collectionIDs = collections.map(\.id).filter { collectionIDs.contains($0) }
        save()
    }

    @discardableResult func addCollection(_ name: String) -> Bool {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...60).contains(value.count), !value.contains(where: { $0.isNewline }),
              !collections.contains(where: { SourceValidation.canonicalName($0.name) == SourceValidation.canonicalName(value) }) else {
            error = L10n.text("Koleksiyon adı 1–60 karakter olmalı ve benzersiz olmalı."); return false
        }
        collections.append(ClipCollection(name: value)); return save()
    }

    func removeCollection(_ collection: ClipCollection) {
        collections.removeAll { $0.id == collection.id }
        for index in clips.indices { clips[index].collectionIDs?.removeAll { $0 == collection.id } }
        save()
    }

    func assign(_ ids: Set<UUID>, to collection: ClipCollection) {
        for index in clips.indices where ids.contains(clips[index].id) {
            var memberships = clips[index].collectionIDs ?? []
            if !memberships.contains(collection.id) { memberships.append(collection.id) }
            clips[index].collectionIDs = memberships
        }
        save()
    }

    func pinMany(_ ids: Set<UUID>) {
        let selected = clips.filter { ids.contains($0.id) }
        let pin = !selected.allSatisfy(\.pinned)
        for index in clips.indices where ids.contains(clips[index].id) { clips[index].pinned = pin }
        save()
    }

    func removeMany(_ ids: Set<UUID>) {
        let removed = clips.filter { ids.contains($0.id) }
        clips.removeAll { ids.contains($0.id) }
        guard save() else { return }
        for clip in removed {
            recognitionTasks.removeValue(forKey: clip.id)?.cancel()
            recognizing.remove(clip.id)
            if let url = assetURL(clip) { try? FileManager.default.removeItem(at: url) }
        }
    }

    @discardableResult func copyMany(_ ids: Set<UUID>, plainText: Bool = false) -> Bool {
        let selected = clips.filter { ids.contains($0.id) }
        guard !selected.isEmpty else { return false }
        if selected.count == 1 { return copy(selected[0], plainText: plainText) }
        if plainText || selected.allSatisfy({ ![.image, .screenshot, .file].contains($0.kind) }) {
            let text = selected.map { [.image, .screenshot].contains($0.kind) ? ($0.extractedText ?? "") : $0.value }.filter { !$0.isEmpty }.joined(separator: "\n\n")
            guard !text.isEmpty else { error = L10n.text("Bu kayıtta kopyalanacak metin yok."); return false }
            board.clearContents(); let success = board.setString(text, forType: .string); count = board.changeCount; return success
        }
        var objects: [NSPasteboardWriting] = []
        for clip in selected {
            if [.image, .screenshot].contains(clip.kind) {
                guard let url = assetURL(clip), let image = NSImage(contentsOf: url) else { error = L10n.text("Kopyalanacak görsel bulunamadı."); return false }
                objects.append(image)
            } else if clip.kind == .file { objects.append(NSURL(fileURLWithPath: clip.value)) }
            else { objects.append(clip.value as NSString) }
        }
        board.clearContents(); let success = board.writeObjects(objects); count = board.changeCount
        if !success { error = L10n.text("İçerik panoya kopyalanamadı.") }
        return success
    }

    func exportBackup(to destination: URL) async {
        guard !transferring else { return }; transferring = true
        defer { transferring = false }
        let history = HistoryDocument(clips: clips, collections: collections)
        let directory = folder
        do {
            try await Task.detached(priority: .userInitiated) {
                var assets: [String: Data] = [:]
                for name in Set(history.clips.compactMap(\.asset)) {
                    guard HistoryBackup.validAssetName(name) else { throw BackupError.invalid }
                    assets[name] = try Data(contentsOf: directory.appendingPathComponent(name))
                }
                let backup = HistoryBackup(history: history, assets: assets)
                try backup.validate()
                let data = try JSONEncoder().encode(backup)
                guard data.count <= HistoryBackup.maximumFileSize else { throw BackupError.tooLarge }
                try data.write(to: destination, options: .atomic)
            }.value
            notice = L10n.text("Yedek kaydedildi.")
        } catch { self.error = L10n.text("Yedekleme başarısız: %@", error.localizedDescription) }
    }

    func importBackup(from source: URL) async {
        guard !transferring, !loadingFailure else { return }; transferring = true
        defer { transferring = false }
        do {
            let backup = try await Task.detached(priority: .userInitiated) { try HistoryBackup.read(source) }.value
            try mergeBackup(backup)
            notice = L10n.text("Yedek içe aktarıldı. Mevcut kayıtlar korundu.")
        } catch { self.error = L10n.text("İçe aktarma başarısız: %@", error.localizedDescription) }
    }

    func mergeBackup(_ backup: HistoryBackup) throws {
        try backup.validate()
        var mergedCollections = collections
        var mapping: [UUID: UUID] = [:]
        for collection in backup.history.collections {
            if let existing = mergedCollections.first(where: { $0.id == collection.id || SourceValidation.canonicalName($0.name) == SourceValidation.canonicalName(collection.name) }) {
                mapping[collection.id] = existing.id
            } else { mergedCollections.append(collection); mapping[collection.id] = collection.id }
        }
        let existingIDs = Set(clips.map(\.id))
        let cutoff = retention.months.flatMap { Calendar.current.date(byAdding: .month, value: -$0, to: Date()) }
        var imported = backup.history.clips.filter { !existingIDs.contains($0.id) && (cutoff == nil || $0.date >= cutoff!) }
        var written: [URL] = []
        do {
            for index in imported.indices {
                imported[index].collectionIDs = imported[index].collectionIDs?.compactMap { mapping[$0] }
                if let name = imported[index].asset, let data = backup.assets[name] {
                    let freshName = UUID().uuidString + ".png"
                    let destination = folder.appendingPathComponent(freshName)
                    guard NSImage(data: data) != nil else { throw BackupError.invalid }
                    try data.write(to: destination, options: .atomic); written.append(destination)
                    imported[index].asset = freshName
                }
            }
            let merged = (clips + imported).sorted { $0.date > $1.date }
            try persist(HistoryDocument(clips: merged, collections: mergedCollections))
            clips = merged; collections = mergedCollections
        } catch { for url in written { try? FileManager.default.removeItem(at: url) }; throw error }
    }

    func exportText(to destination: URL, ids: Set<UUID> = []) async {
        guard !transferring else { return }; transferring = true
        defer { transferring = false }
        let text = clips.filter { ids.isEmpty || ids.contains($0.id) }.map {
            [.image, .screenshot].contains($0.kind) ? ($0.extractedText ?? "") : $0.value
        }.filter { !$0.isEmpty }.joined(separator: "\n\n")
        do {
            try await Task.detached { try text.write(to: destination, atomically: true, encoding: .utf8) }.value
            notice = L10n.text("Metin dışa aktarıldı.")
        } catch { self.error = error.localizedDescription }
    }

 }
