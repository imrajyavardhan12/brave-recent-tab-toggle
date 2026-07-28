import Foundation

public final class NativeMessageSink: @unchecked Sendable {
    private let output: FileHandle
    private let writer: NativeMessageWriter
    private let lock = NSLock()

    public init(
        output: FileHandle = .standardOutput,
        writer: NativeMessageWriter = NativeMessageWriter()
    ) {
        self.output = output
        self.writer = writer
    }

    public func send(_ message: [String: String]) throws {
        let frame = try writer.frame(message)
        try lock.withLock {
            try output.write(contentsOf: frame)
        }
    }
}
