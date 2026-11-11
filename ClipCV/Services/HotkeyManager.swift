import Carbon
import Foundation

@MainActor
final class HotkeyManager {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var onPressed: (() -> Void)?

    func register(_ hotkey: Hotkey) {
        unregister()
        guard !hotkey.isCleared else { return }
        installHandlerIfNeeded()
        var ref: EventHotKeyRef?
        RegisterEventHotKey(
            UInt32(hotkey.keyCode),
            hotkey.carbonModifiers,
            EventHotKeyID(signature: FourCharCode(0x434C4356), id: 1),
            GetApplicationEventTarget(),
            0,
            &ref
        )
        hotKey = ref
    }

    func unregister() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                DispatchQueue.main.async {
                    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                    MainActor.assumeIsolated { manager.onPressed?() }
                }
                return noErr
            },
            1,
            &spec,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler
        )
    }
}
