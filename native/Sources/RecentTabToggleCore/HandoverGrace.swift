import Foundation

/// Holds back hotkey conflicts briefly after a host takes over leadership.
///
/// A new leader can try the exclusive registration before the previous holder has released
/// it: the old leader steps down only on its next 1-second timer tick, and the window server
/// frees an exited process's hotkey asynchronously. Reporting that conflict would flash a
/// false error in every profile's diagnostics. Outside the grace, conflicts are real and are
/// reported at once.
public struct HandoverGrace {
  private let duration: TimeInterval
  private var termStart: TimeInterval?

  public init(duration: TimeInterval = 2.5) {
    self.duration = duration
  }

  /// `now` must come from a monotonic clock so wall-clock changes cannot stretch the grace.
  public mutating func beginTerm(at now: TimeInterval) {
    termStart = now
  }

  public mutating func endTerm() {
    termStart = nil
  }

  /// Returns the state to report, or nil for a conflict during the handover grace.
  public func report(_ state: HotKeyState, at now: TimeInterval) -> HotKeyState? {
    guard state == .conflict, let termStart, now - termStart < duration else { return state }
    return nil
  }
}
