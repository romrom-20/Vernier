import AppKit
import Carbon

/// Registers one named key combination; does not monitor or record general keyboard input.
/// Owned for the coordinator's lifetime and explicitly stopped at application termination.
@MainActor final class GlobalShortcut {
    static let display = "⌃⌥⌘V"
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: @MainActor () -> Void
    init(action: @escaping @MainActor () -> Void) { self.action = action }

    func start() -> OSStatus {
        stop()
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                    MemoryLayout<EventHotKeyID>.size, nil, &identifier) == noErr else { return OSStatus(eventNotHandledErr) }
            return MainActor.assumeIsolated {
                guard identifier.signature == 0x56524E52, identifier.id == 1 else { return OSStatus(eventNotHandledErr) }
                Unmanaged<GlobalShortcut>.fromOpaque(context).takeUnretainedValue().action()
                return noErr
            }
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else { return status }
        let registration = RegisterEventHotKey(UInt32(kVK_ANSI_V), UInt32(controlKey | optionKey | cmdKey),
                                               EventHotKeyID(signature: 0x56524E52, id: 1), GetApplicationEventTarget(),
                                               OptionBits(kEventHotKeyExclusive), &hotKey)
        if registration != noErr { stop() }
        return registration
    }
    func stop() {
        if let hotKey { UnregisterEventHotKey(hotKey); self.hotKey = nil }
        if let handler { RemoveEventHandler(handler); self.handler = nil }
    }
}
