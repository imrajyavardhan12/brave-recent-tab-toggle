import Foundation

public struct NativeMessageWriter: Sendable {
    public init() {}

    public func frame(_ message: [String: String]) throws -> Data {
        let payload = try JSONSerialization.data(
            withJSONObject: message,
            options: [.sortedKeys]
        )
        var length = UInt32(payload.count).littleEndian
        var frame = withUnsafeBytes(of: &length) { Data($0) }
        frame.append(payload)
        return frame
    }
}
