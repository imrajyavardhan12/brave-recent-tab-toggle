public enum HotKeyState: String, Sendable {
    case active
    case inactive
    case conflict
}

public protocol HotKeyRegistering: AnyObject {
    func register() -> HotKeyState
    func unregister()
}

public final class HotKeyActivationController {
    private let registrar: HotKeyRegistering
    private let policy: HotKeyPolicy
    private var isRegistered = false

    public init(
        registrar: HotKeyRegistering,
        policy: HotKeyPolicy = HotKeyPolicy()
    ) {
        self.registrar = registrar
        self.policy = policy
    }

    @discardableResult
    public func update(frontmostBundleID: String?) -> HotKeyState {
        guard policy.shouldRegister(frontmostBundleID: frontmostBundleID) else {
            if isRegistered {
                registrar.unregister()
                isRegistered = false
            }
            return .inactive
        }

        if isRegistered {
            return .active
        }

        let state = registrar.register()
        isRegistered = state == .active
        return state
    }
}
