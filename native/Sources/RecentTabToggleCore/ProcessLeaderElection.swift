import Darwin
import Foundation

public enum LeaderElectionError: Error {
  case cannotOpenLockFile(URL, errno: Int32)
}

public final class ProcessLeaderElection: @unchecked Sendable {
  private let descriptor: Int32
  private let lock = NSLock()
  private var leader = false

  public init(lockFile: URL) throws {
    try FileManager.default.createDirectory(
      at: lockFile.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    descriptor = lockFile.path.withCString {
      Darwin.open($0, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
    }
    guard descriptor >= 0 else {
      throw LeaderElectionError.cannotOpenLockFile(lockFile, errno: errno)
    }
  }

  public func tryAcquire() -> Bool {
    lock.withLock {
      if leader { return true }
      leader = flock(descriptor, LOCK_EX | LOCK_NB) == 0
      return leader
    }
  }

  public func release() {
    lock.withLock {
      guard leader else { return }
      _ = flock(descriptor, LOCK_UN)
      leader = false
    }
  }

  deinit {
    release()
    Darwin.close(descriptor)
  }
}
