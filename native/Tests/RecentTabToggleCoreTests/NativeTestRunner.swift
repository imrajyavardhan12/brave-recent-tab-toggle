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
    if CommandLine.arguments.contains("--hold-hotkey") {
      let registrar = CarbonHotKeyRegistrar {}
      print(registrar.register().rawValue)
      fflush(stdout)
      _ = FileHandle.standardInput.readDataToEndOfFile()
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
    try steppingDownReleasesTheHotKey()
    print("✓ stepping down releases the hotkey")
    try aReplacedLockFileLeavesOneLeader()
    print("✓ a replaced lock file leaves exactly one leader")
    try aRemovedLockDirectoryLeavesOneLeader()
    print("✓ a removed lock directory leaves exactly one leader")
    if try aHotKeyHeldByAnotherProcessIsAConflict() {
      print("✓ a hotkey held by another process is reported as a conflict")
    } else {
      print(
        "- skipped: hotkey conflict test (Control + ` cannot be registered here; "
          + "it needs a GUI login session and no app reserving the shortcut)"
      )
    }
    try shortcutEventsFanOutToConnectedHosts()
    print("✓ shortcut events fan out to connected hosts")
  }

  /// Returns false when this environment cannot register the hotkey at all.
  static func aHotKeyHeldByAnotherProcessIsAConflict() throws -> Bool {
    let holder = Process()
    holder.executableURL = Bundle.main.executableURL
    holder.arguments = ["--hold-hotkey"]
    let input = Pipe()
    let output = Pipe()
    holder.standardInput = input
    holder.standardOutput = output
    try holder.run()
    var released = false
    let release = {
      guard !released else { return }
      released = true
      try? input.fileHandleForWriting.close()
      holder.waitUntilExit()
    }
    defer { release() }

    var ready = pollfd(
      fd: output.fileHandleForReading.fileDescriptor,
      events: Int16(POLLIN),
      revents: 0
    )
    guard poll(&ready, 1, 5_000) == 1 else {
      holder.terminate()
      throw TestFailure(description: "the holding process did not report its hotkey state")
    }
    let held = String(decoding: output.fileHandleForReading.availableData, as: UTF8.self)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    // Only a clean registration refusal is environmental; anything else is a defect.
    if held == "conflict" { return false }
    try expect(held == "active", "the holding process reported \"\(held)\" instead of a state")

    let registrar = CarbonHotKeyRegistrar {}
    try expect(
      registrar.register() == .conflict,
      "a hotkey held by another process must be reported as a conflict"
    )
    release()
    // The window server releases a terminated process's hotkeys asynchronously.
    var state = registrar.register()
    for _ in 0..<60 where state != .active {
      RunLoop.main.run(until: Date().addingTimeInterval(0.05))
      state = registrar.register()
    }
    try expect(state == .active, "the hotkey should register once the other process releases it")
    registrar.unregister()
    return true
  }

  static func aReplacedLockFileLeavesOneLeader() throws {
    let directory = temporaryLockDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let lockFile = directory.appendingPathComponent("native-host.lock")

    let leader = try ProcessLeaderElection(lockFile: lockFile)
    let follower = try ProcessLeaderElection(lockFile: lockFile)
    try expect(leader.tryAcquire(), "first host should become leader")
    try FileManager.default.removeItem(at: lockFile)
    let newcomer = try ProcessLeaderElection(lockFile: lockFile)

    try expect(newcomer.tryAcquire(), "a host using the new lock file should lead")
    try expect(!leader.tryAcquire(), "the leader of a removed lock file must step down")
    try expect(!follower.tryAcquire(), "a follower must not lead alongside the new leader")
  }

  static func aRemovedLockDirectoryLeavesOneLeader() throws {
    let directory = temporaryLockDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let lockFile = directory.appendingPathComponent("native-host.lock")

    let leader = try ProcessLeaderElection(lockFile: lockFile)
    let follower = try ProcessLeaderElection(lockFile: lockFile)
    try expect(leader.tryAcquire(), "first host should become leader")
    try FileManager.default.removeItem(at: directory)

    try expect(follower.tryAcquire(), "a follower should lead on a recreated lock file")
    try expect(!leader.tryAcquire(), "the leader of a removed lock file must step down")
  }

  static func steppingDownReleasesTheHotKey() throws {
    let registrar = RecordingHotKeyRegistrar()
    let controller = HotKeyActivationController(registrar: registrar)
    _ = controller.update(frontmostBundleID: "com.brave.Browser")

    controller.deactivate()
    let state = controller.update(frontmostBundleID: "com.brave.Browser")

    try expect(registrar.unregistrations == 1, "stepping down should unregister the hotkey")
    try expect(state == .active, "a returning leader should register the hotkey again")
    try expect(registrar.registrations == 2, "a returning leader should register once more")
  }

  static func temporaryLockDirectory() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("recent-tab-toggle-tests-\(UUID().uuidString)", isDirectory: true)
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
