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
  public static let braveStableBundleID = "com.brave.Browser"

  private let registrar: HotKeyRegistering
  private let targetBundleID: String
  private var isRegistered = false

  public init(
    registrar: HotKeyRegistering,
    targetBundleID: String = HotKeyActivationController.braveStableBundleID
  ) {
    self.registrar = registrar
    self.targetBundleID = targetBundleID
  }

  @discardableResult
  public func update(frontmostBundleID: String?) -> HotKeyState {
    guard frontmostBundleID == targetBundleID else {
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
