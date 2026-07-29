// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "RecentTabToggleNative",
  platforms: [.macOS(.v13)],
  products: [
    .executable(name: "recent-tab-toggle-host", targets: ["RecentTabToggleHost"]),
    .executable(
      name: "recent-tab-toggle-native-tests",
      targets: ["RecentTabToggleNativeTests"]
    ),
  ],
  targets: [
    .target(name: "RecentTabToggleCore"),
    .executableTarget(
      name: "RecentTabToggleHost",
      dependencies: ["RecentTabToggleCore"]
    ),
    .executableTarget(
      name: "RecentTabToggleNativeTests",
      dependencies: ["RecentTabToggleCore"],
      path: "Tests/RecentTabToggleCoreTests"
    ),
  ]
)
