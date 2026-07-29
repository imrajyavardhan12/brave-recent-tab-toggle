import Foundation

public final class DistributedEventBus: @unchecked Sendable {
  public static let defaultNamespace = "org.recenttabtoggle.host"

  private let toggleName: Notification.Name
  private let statusName: Notification.Name
  private let statusRequestName: Notification.Name
  private let center: DistributedNotificationCenter
  private let lock = NSLock()
  private var observers: [NSObjectProtocol] = []

  public init(
    namespace: String = DistributedEventBus.defaultNamespace,
    center: DistributedNotificationCenter = .default()
  ) {
    toggleName = Notification.Name("\(namespace).toggle")
    statusName = Notification.Name("\(namespace).status")
    statusRequestName = Notification.Name("\(namespace).status-request")
    self.center = center
  }

  public func onToggle(_ handler: @escaping @Sendable () -> Void) {
    observe(name: toggleName) { _ in handler() }
  }

  public func onStatus(_ handler: @escaping @Sendable (HotKeyState) -> Void) {
    observe(name: statusName) { notification in
      guard
        let rawValue = notification.userInfo?["hotkey"] as? String,
        let state = HotKeyState(rawValue: rawValue)
      else { return }
      handler(state)
    }
  }

  public func onStatusRequest(_ handler: @escaping @Sendable () -> Void) {
    observe(name: statusRequestName) { _ in handler() }
  }

  public func broadcastToggle() {
    post(name: toggleName)
  }

  public func broadcastStatus(_ state: HotKeyState) {
    post(name: statusName, userInfo: ["hotkey": state.rawValue])
  }

  public func requestStatus() {
    post(name: statusRequestName)
  }

  private func observe(
    name: Notification.Name,
    handler: @escaping @Sendable (Notification) -> Void
  ) {
    let observer = center.addObserver(
      forName: name,
      object: nil,
      queue: .main,
      using: handler
    )
    lock.withLock { observers.append(observer) }
  }

  private func post(
    name: Notification.Name,
    userInfo: [AnyHashable: Any]? = nil
  ) {
    center.postNotificationName(
      name,
      object: nil,
      userInfo: userInfo,
      deliverImmediately: true
    )
  }

  deinit {
    for observer in observers {
      center.removeObserver(observer)
    }
  }
}
