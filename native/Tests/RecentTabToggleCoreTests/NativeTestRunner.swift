import Foundation
import RecentTabToggleCore

struct TestFailure: Error, CustomStringConvertible {
  let description: String
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
  guard condition() else { throw TestFailure(description: message) }
}

@main
struct NativeTestRunner {
  static func main() throws {
    if CommandLine.arguments.contains("--broadcast-toggle") {
      let namespace =
        ProcessInfo.processInfo.environment["RTT_EVENT_NAMESPACE"]
        ?? DistributedEventBus.defaultNamespace
      let bus = DistributedEventBus(namespace: namespace)
      bus.broadcastToggle()
      RunLoop.main.run(until: Date().addingTimeInterval(0.1))
      return
    }

    try messageSinkWritesACompleteFrame()
    print("✓ a message sink writes a complete Chromium frame")
    try hotkeyIsOnlyActiveForBraveStable()
    print("✓ the hotkey is only active for Brave Stable")
    try hotkeyFollowsBraveFocus()
    print("✓ the hotkey follows Brave focus")
    try onlyOneNativeHostBecomesLeader()
    print("✓ only one native host becomes hotkey leader")
    try shortcutEventsFanOutToConnectedHosts()
    print("✓ shortcut events fan out to connected hosts")
  }

  static func shortcutEventsFanOutToConnectedHosts() throws {
    let namespace = "org.recenttabtoggle.tests.\(UUID().uuidString)"
    let first = DistributedEventBus(namespace: namespace)
    let second = DistributedEventBus(namespace: namespace)
    let received = LockedCounter()
    first.onToggle { received.increment() }
    second.onToggle { received.increment() }

    first.broadcastToggle()
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))

    try expect(received.value == 2, "each connected host should receive one shortcut event")
  }

  static func onlyOneNativeHostBecomesLeader() throws {
    let lockFile = FileManager.default.temporaryDirectory
      .appendingPathComponent("recent-tab-toggle-tests-\(UUID().uuidString).lock")
    defer { try? FileManager.default.removeItem(at: lockFile) }

    let first = try ProcessLeaderElection(lockFile: lockFile)
    let second = try ProcessLeaderElection(lockFile: lockFile)

    try expect(first.tryAcquire(), "first host should become leader")
    try expect(!second.tryAcquire(), "second host must remain a follower")
    first.release()
    try expect(second.tryAcquire(), "follower should take over after leader exits")
  }

  static func hotkeyFollowsBraveFocus() throws {
    let registrar = RecordingHotKeyRegistrar()
    let controller = HotKeyActivationController(registrar: registrar)

    let active = controller.update(frontmostBundleID: "com.brave.Browser")
    let inactive = controller.update(frontmostBundleID: "com.apple.Terminal")

    try expect(active == .active, "hotkey should become active for Brave")
    try expect(inactive == .inactive, "hotkey should become inactive outside Brave")
    try expect(registrar.registrations == 1, "hotkey should be registered once")
    try expect(registrar.unregistrations == 1, "hotkey should be unregistered once")
  }

  static func hotkeyIsOnlyActiveForBraveStable() throws {
    let registrar = RecordingHotKeyRegistrar()
    let controller = HotKeyActivationController(registrar: registrar)

    _ = controller.update(frontmostBundleID: "com.brave.Browser.beta")
    _ = controller.update(frontmostBundleID: "com.apple.Terminal")
    _ = controller.update(frontmostBundleID: nil)
    try expect(
      registrar.registrations == 0,
      "non-stable Brave applications must not register the hotkey"
    )

    let state = controller.update(frontmostBundleID: "com.brave.Browser")
    try expect(state == .active, "Brave Stable should activate the hotkey")
    try expect(registrar.registrations == 1, "Brave should register once")
  }

  static func messageSinkWritesACompleteFrame() throws {
    let pipe = Pipe()
    let sink = NativeMessageSink(output: pipe.fileHandleForWriting)

    try sink.send(["type": "toggle"])
    try pipe.fileHandleForWriting.close()

    let frame = pipe.fileHandleForReading.readDataToEndOfFile()
    let length = frame.prefix(4).withUnsafeBytes {
      UInt32(littleEndian: $0.loadUnaligned(as: UInt32.self))
    }
    try expect(Int(length) == frame.count - 4, "frame length prefix is incorrect")

    let payload =
      try JSONSerialization.jsonObject(
        with: frame.dropFirst(4)
      ) as? [String: String]
    try expect(payload == ["type": "toggle"], "frame payload is incorrect")
  }
}

final class LockedCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var count = 0

  var value: Int { lock.withLock { count } }
  func increment() { lock.withLock { count += 1 } }
}

final class RecordingHotKeyRegistrar: HotKeyRegistering {
  var registrations = 0
  var unregistrations = 0

  func register() -> HotKeyState {
    registrations += 1
    return .active
  }

  func unregister() {
    unregistrations += 1
  }
}
