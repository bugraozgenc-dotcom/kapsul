import Combine
import Foundation
import Sparkle

@MainActor final class AppUpdater: ObservableObject {
    private let controller: SPUStandardUpdaterController
    @Published private(set) var canCheckForUpdates = false
    @Published var automaticallyChecksForUpdates = false {
        didSet {
            if controller.updater.automaticallyChecksForUpdates != automaticallyChecksForUpdates {
                controller.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
            }
        }
    }
    private var subscriptions = Set<AnyCancellable>()

    init() {
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$canCheckForUpdates)
        controller.updater.publisher(for: \.automaticallyChecksForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in self?.automaticallyChecksForUpdates = value }
            .store(in: &subscriptions)
        // Plain `swift run` has no application bundle or update configuration.
        if Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") != nil {
            controller.startUpdater()
        }
    }

    func checkForUpdates() { controller.checkForUpdates(nil) }

    var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
    }
}
