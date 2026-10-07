import AppKit
import Darwin
@main struct ScreenshotChecks {
    @MainActor static func main() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let old = folder.appendingPathComponent("Screenshot old.png")
        try Data([1]).write(to: old)
        let monitor = ScreenshotMonitor(directory: folder, useSpotlight: false)
        var paths: [String] = []
        var succeed = true
        monitor.onScreenshot = { url in paths.append(url.lastPathComponent); return succeed }
        let shot = folder.appendingPathComponent("Screenshot new.png")
        try Data([1]).write(to: shot)
        let tagged = folder.appendingPathComponent("custom-name.png")
        try Data([1]).write(to: tagged)
        let flag = try PropertyListSerialization.data(fromPropertyList: true, format: .binary, options: 0)
        let status = flag.withUnsafeBytes { setxattr(tagged.path, "com.apple.metadata:kMDItemIsScreenCapture", $0.baseAddress, flag.count, 0, 0) }
        precondition(status == 0)
        try Data([1]).write(to: folder.appendingPathComponent("ordinary-image.png"))
        monitor.scanFolder(); monitor.scanFolder()
        precondition(Set(paths) == [shot.lastPathComponent, tagged.lastPathComponent])
        precondition(paths.count == 2)
        precondition(!ScreenshotMonitor.isScreenshot(folder.appendingPathComponent("ordinary-image.png")))
        precondition(ScreenshotMonitor.isScreenshot(tagged))
        succeed = false
        let retry = folder.appendingPathComponent("Ekran görüntüsü new.png")
        try Data([1]).write(to: retry)
        monitor.scanFolder()
        succeed = true
        monitor.scanFolder(); monitor.scanFolder()
        precondition(paths.filter { $0 == retry.lastPathComponent }.count == 2)
        print("Ekran görüntüsü: eski dosyaları atlama, metadata, Türkçe ad, tekrar kaydetmeme ve yazım sonrası yeniden deneme kontrolleri geçti.")
    }
}
