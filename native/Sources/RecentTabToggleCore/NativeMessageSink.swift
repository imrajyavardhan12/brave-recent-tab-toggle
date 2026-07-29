import Foundation

public final class NativeMessageSink: @unchecked Sendable {
  private let output: FileHandle
  private let lock = NSLock()

  public init(output: FileHandle = .standardOutput) {
    self.output = output
  }

  public func send(_ message: [String: String]) throws {
    let payload = try JSONSerialization.data(
      withJSONObject: message,
      options: [.sortedKeys]
    )
    var length = UInt32(payload.count).littleEndian
    var frame = withUnsafeBytes(of: &length) { Data($0) }
    frame.append(payload)

    try lock.withLock {
      try output.write(contentsOf: frame)
    }
  }
}
