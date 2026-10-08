import AppKit
import Carbon
import Combine

@MainActor final class PanelController: ObservableObject {
    static let shared = PanelController()
    @Published var shortcut: String {
        didSet { UserDefaults.standard.set(shortcut, forKey: "panelShortcut"); registerShortcut() }
    }
    @Published private(set) var shortcutError: String?
    var showPanel: (() -> Void)?
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var started = false

    private init() { shortcut = UserDefaults.standard.string(forKey: "panelShortcut") ?? "option-space" }

    func start() {
        guard !started else { return }; started = true
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context, let event else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard result == noErr, identifier.signature == 0x4B415053, identifier.id == 1 else { return OSStatus(eventNotHandledErr) }
            let controller = Unmanaged<PanelController>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in controller.open() }
            return noErr
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else { shortcutError = L10n.text("Kısayol kaydedilemedi. Başka bir kısayol seç."); return }
        registerShortcut()
    }

    private func registerShortcut() {
        if let hotKey { UnregisterEventHotKey(hotKey); self.hotKey = nil }
        shortcutError = nil
        guard started, shortcut != "disabled" else { return }
        let modifiers: UInt32
        switch shortcut {
        case "command-shift-space": modifiers = UInt32(cmdKey | shiftKey)
        case "control-option-space": modifiers = UInt32(controlKey | optionKey)
        default: modifiers = UInt32(optionKey)
        }
        let result = RegisterEventHotKey(UInt32(kVK_Space), modifiers, EventHotKeyID(signature: 0x4B415053, id: 1), GetApplicationEventTarget(), 0, &hotKey)
        if result != noErr { shortcutError = L10n.text("Kısayol kaydedilemedi. Başka bir kısayol seç.") }
    }

    func open() {
        showPanel?()
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

}
