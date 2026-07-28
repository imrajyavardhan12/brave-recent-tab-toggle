import Carbon
import Foundation

public final class CarbonHotKeyRegistrar: HotKeyRegistering, @unchecked Sendable {
    private static let signature: OSType = 0x52545431 // RTT1
    private static let identifier: UInt32 = 1

    private let onTrigger: @Sendable () -> Void
    private var eventHandler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?

    public init(onTrigger: @escaping @Sendable () -> Void) {
        self.onTrigger = onTrigger

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, context in
                guard let context else { return OSStatus(eventNotHandledErr) }
                let registrar = Unmanaged<CarbonHotKeyRegistrar>
                    .fromOpaque(context)
                    .takeUnretainedValue()
                registrar.onTrigger()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    public func register() -> HotKeyState {
        guard eventHandler != nil else { return .conflict }
        if hotKey != nil { return .active }

        let identifier = EventHotKeyID(
            signature: Self.signature,
            id: Self.identifier
        )
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_Grave),
            UInt32(controlKey),
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
        if status == noErr { return .active }
        hotKey = nil
        return .conflict
    }

    public func unregister() {
        guard let hotKey else { return }
        UnregisterEventHotKey(hotKey)
        self.hotKey = nil
    }

    deinit {
        unregister()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
}
