import AppKit
import Darwin

/// Observes only screenshots created while this session is running.
@MainActor final class ScreenshotMonitor {
    private let query = NSMetadataQuery()
    private let startedAt = Date()
    private var seen = Set<String>()
    private var observers: [NSObjectProtocol] = []
    private var timer: Timer?
    private let directory: URL
    var onScreenshot: ((URL) -> Bool)?

    init(directory: URL? = nil, useSpotlight: Bool = true) {
        let configured = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location")
        self.directory = directory ?? configured.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
            ?? FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        // Establish a baseline so old screenshots aren't imported on startup.
        for url in folderFiles() { seen.insert(url.path) }
        if useSpotlight {
            query.searchScopes = [NSMetadataQueryUserHomeScope]
            query.predicate = NSPredicate(format: "kMDItemIsScreenCapture == 1 && kMDItemFSCreationDate >= %@", startedAt as NSDate)
            for name in [Notification.Name.NSMetadataQueryDidFinishGathering, .NSMetadataQueryDidUpdate] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: query, queue: .main) { [weak self] _ in
                    Task { @MainActor in self?.scanQuery() }
                })
            }
            query.start()
        }
        // Directory fallback also handles screenshots before Spotlight indexes them.
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.scanFolder() }
        }
    }
    deinit {
        timer?.invalidate()
        query.stop()
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
    }
    private func folderFiles() -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey, .isRegularFileKey], options: [.skipsHiddenFiles])) ?? []
    }
    private func accept(_ url: URL) {
        guard !seen.contains(url.path) else { return }
        // A file may still be writing: mark seen only after successful import.
        if onScreenshot?(url) == true { seen.insert(url.path) }
    }
    private func scanQuery() {
        query.disableUpdates()
        defer { query.enableUpdates() }
        for item in query.results.compactMap({ $0 as? NSMetadataItem }) {
            if let path = item.value(forAttribute: NSMetadataItemPathKey) as? String { accept(URL(fileURLWithPath: path)) }
        }
    }
    func scanFolder() {
        for url in folderFiles() {
            guard !seen.contains(url.path), let values = try? url.resourceValues(forKeys: [.creationDateKey, .isRegularFileKey]),
                  values.isRegularFile == true, let created = values.creationDate, created >= startedAt else { continue }
            guard Self.isScreenshot(url) else { continue }
            accept(url)
        }
    }
    nonisolated static func isScreenshot(_ url: URL) -> Bool {
        let key = "com.apple.metadata:kMDItemIsScreenCapture"
        let size = getxattr(url.path, key, nil, 0, 0, 0)
        if size > 0 && size < 4096 {
            var bytes = [UInt8](repeating: 0, count: size)
            let read = bytes.withUnsafeMutableBytes { getxattr(url.path, key, $0.baseAddress, size, 0, 0) }
            if read == size, let flag = try? PropertyListSerialization.propertyList(from: Data(bytes), format: nil) {
                if let bool = flag as? Bool, bool { return true }
                if let text = flag as? String, ["1", "true"].contains(text.lowercased()) { return true }
            }
        }
        // macOS may omit the metadata initially; recognize its default filenames.
        let name = url.deletingPathExtension().lastPathComponent.lowercased()
        let prefixes = ["screenshot ", "screen shot ", "ekran görüntüsü ", "bildschirmfoto ", "capture d’écran ", "capture d'écran "]
        return ["png", "jpg", "jpeg", "heic", "tiff"].contains(url.pathExtension.lowercased()) && prefixes.contains { name.hasPrefix($0) }
    }
}
