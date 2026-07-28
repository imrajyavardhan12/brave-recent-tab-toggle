public struct HotKeyPolicy: Sendable {
    public static let braveStableBundleID = "com.brave.Browser"

    private let targetBundleID: String

    public init(targetBundleID: String = HotKeyPolicy.braveStableBundleID) {
        self.targetBundleID = targetBundleID
    }

    public func shouldRegister(frontmostBundleID: String?) -> Bool {
        frontmostBundleID == targetBundleID
    }
}
