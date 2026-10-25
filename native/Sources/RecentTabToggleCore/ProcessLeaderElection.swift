import Darwin
import Foundation

public enum LeaderElectionError: Error {
  case cannotOpenLockFile(URL, errno: Int32)
}

/// Elects one host per user through an advisory lock on a shared file.
///
/// A lock only excludes processes that open the same file. If the file is removed (by a cache
/// cleaner or an uninstall) a new host would lock a fresh file and lead alongside the old leader,
/// so every attempt confirms the held descriptor is still the file at `lockFile`.
public final class ProcessLeaderElection: @unchecked Sendable {
  private let lockFile: URL
  private let lock = NSLock()
  private var descriptor: Int32 = -1
  private var leader = false

  public init(lockFile: URL) throws {
    self.lockFile = lockFile
    guard openLockFile() else {
      throw LeaderElectionError.cannotOpenLockFile(lockFile, errno: errno)
    }
  }

  /// Acquires free leadership, and gives it up if the held lock file has been removed.
  public func tryAcquire() -> Bool {
    lock.withLock {
      if leader {
        if holdsCurrentLockFile() { return true }
        _ = flock(descriptor, LOCK_UN)
        leader = false
      }
      if !holdsCurrentLockFile() && !openLockFile() { return false }
      guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else { return false }
      guard holdsCurrentLockFile() else {
        // The file was replaced between opening and locking; retry on the next attempt.
        _ = flock(descriptor, LOCK_UN)
        return false
      }
      leader = true
      return true
    }
  }

  public func release() {
    lock.withLock {
      guard leader else { return }
      _ = flock(descriptor, LOCK_UN)
      leader = false
    }
  }

  private func openLockFile() -> Bool {
    if descriptor >= 0 { Darwin.close(descriptor) }
    try? FileManager.default.createDirectory(
      at: lockFile.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    descriptor = lockFile.path.withCString {
      Darwin.open($0, O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
    }
    return descriptor >= 0
  }

  private func holdsCurrentLockFile() -> Bool {
    guard descriptor >= 0 else { return false }
    var held = stat()
    var current = stat()
    guard fstat(descriptor, &held) == 0, stat(lockFile.path, &current) == 0 else {
      return false
    }
    return held.st_dev == current.st_dev && held.st_ino == current.st_ino
  }

  deinit {
    release()
    if descriptor >= 0 { Darwin.close(descriptor) }
  }
}
