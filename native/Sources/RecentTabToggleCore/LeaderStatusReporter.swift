import Foundation

/// Decides which hotkey states the leader broadcasts to every profile.
///
/// The leader broadcasts a state when it changes, when a heartbeat asks for a repeat, and
/// when a leadership term begins. A conflict right after taking over from a previous leader
/// is held (see ``HandoverGrace``); while it is held there is no current state, so status
/// requests go unanswered and a requested broadcast waits until the hold resolves.
public struct LeaderStatusReporter {
  private var grace: HandoverGrace
  /// The state every profile last heard; nil forces the next observed state out.
  private var broadcast: HotKeyState?
  private var holdingConflict = false

  public init(grace duration: TimeInterval = 2.5) {
    grace = HandoverGrace(duration: duration)
  }

  /// A cold start has no previous holder to wait for, so only a takeover gets the grace.
  public mutating func beginTerm(at now: TimeInterval, afterPreviousLeader: Bool) {
    if afterPreviousLeader {
      grace.beginTerm(at: now)
    } else {
      grace.endTerm()
    }
    broadcast = nil
    holdingConflict = false
  }

  public mutating func endTerm() {
    grace.endTerm()
    broadcast = nil
    holdingConflict = false
  }

  /// Repeats the current state on the next observation, for hosts that missed a broadcast.
  public mutating func requestBroadcast() {
    broadcast = nil
  }

  /// Returns the state to broadcast for a new reading, or nil when nothing should be sent.
  public mutating func observe(_ state: HotKeyState, at now: TimeInterval) -> HotKeyState? {
    guard let reported = grace.report(state, at: now) else {
      holdingConflict = true
      return nil
    }
    holdingConflict = false
    guard reported != broadcast else { return nil }
    broadcast = reported
    return reported
  }

  /// The state to answer a follower's status request with, if there is a current one.
  public var statusForRequest: HotKeyState? {
    holdingConflict ? nil : broadcast
  }
}
