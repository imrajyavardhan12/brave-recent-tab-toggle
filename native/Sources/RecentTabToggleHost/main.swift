import AppKit
import Darwin
import Foundation
import RecentTabToggleCore

final class HostRuntime: @unchecked Sendable {
  private let sink = NativeMessageSink()
  private let bus: DistributedEventBus
  private let election: ProcessLeaderElection
  private let registrar: CarbonHotKeyRegistrar
  private let controller: HotKeyActivationController

  private var isLeader = false
  private var lastState = HotKeyState.inactive
  private var workspaceObserver: NSObjectProtocol?
  private var timer: Timer?

  init(environment: [String: String] = ProcessInfo.processInfo.environment) throws {
    let defaultCacheDirectory = FileManager.default.urls(
      for: .cachesDirectory,
      in: .userDomainMask
    )[0].appendingPathComponent("RecentTabToggle", isDirectory: true)
    let coordinationDirectory =
      environment["RTT_COORDINATION_ROOT"]
      .map { URL(fileURLWithPath: $0, isDirectory: true) }
      ?? defaultCacheDirectory
    let namespace =
      environment["RTT_EVENT_NAMESPACE"]
      ?? DistributedEventBus.defaultNamespace
    let targetBundleID =
      environment["RTT_TARGET_BUNDLE_ID"]
      ?? HotKeyActivationController.braveStableBundleID

    bus = DistributedEventBus(namespace: namespace)
    election = try ProcessLeaderElection(
      lockFile: coordinationDirectory.appendingPathComponent("native-host.lock")
    )
    registrar = CarbonHotKeyRegistrar { [bus] in
      bus.broadcastToggle()
    }
    controller = HotKeyActivationController(
      registrar: registrar,
      targetBundleID: targetBundleID
    )
  }

  func start() throws {
    bus.onToggle { [sink] in
      Self.sendOrTerminate(["type": "toggle"], to: sink)
    }
    bus.onStatus { [sink] state in
      Self.sendOrTerminate(
        [
          "type": "status",
          "helper": "connected",
          "hotkey": state.rawValue,
        ], to: sink)
    }
    bus.onStatusRequest { [weak self] in
      guard let self, self.isLeader else { return }
      self.bus.broadcastStatus(self.lastState)
    }

    try sink.send([
      "type": "status",
      "helper": "connected",
      "hotkey": "unknown",
    ])

    workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.refreshHotKey(forceBroadcast: false)
    }

    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {
      [weak self] _ in self?.maintainLeadership()
    }
    maintainLeadership()
    monitorBrowserConnection()
  }

  private func maintainLeadership() {
    if !isLeader {
      isLeader = election.tryAcquire()
      if !isLeader {
        bus.requestStatus()
        return
      }
      refreshHotKey(forceBroadcast: true)
      return
    }
    refreshHotKey(forceBroadcast: false)
  }

  private func refreshHotKey(forceBroadcast: Bool) {
    guard isLeader else { return }
    let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    let state = controller.update(frontmostBundleID: bundleID)
    if forceBroadcast || state != lastState {
      lastState = state
      bus.broadcastStatus(state)
    }
  }

  private static func sendOrTerminate(
    _ message: [String: String],
    to sink: NativeMessageSink
  ) {
    do {
      try sink.send(message)
    } catch {
      FileHandle.standardError.write(
        Data("Recent Tab Toggle native messaging failed: \(error)\n".utf8)
      )
      exit(EXIT_FAILURE)
    }
  }

  private func monitorBrowserConnection() {
    Thread.detachNewThread {
      while !FileHandle.standardInput.availableData.isEmpty {}
      exit(EXIT_SUCCESS)
    }
  }

  deinit {
    if let workspaceObserver {
      NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
    }
    timer?.invalidate()
  }
}

do {
  let application = NSApplication.shared
  application.setActivationPolicy(.prohibited)
  let runtime = try HostRuntime()
  try runtime.start()
  application.run()
} catch {
  FileHandle.standardError.write(
    Data("Recent Tab Toggle helper failed: \(error)\n".utf8)
  )
  exit(EXIT_FAILURE)
}
