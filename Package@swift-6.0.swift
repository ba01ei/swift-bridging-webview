// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "BridgingWebView",
  platforms: [
    .iOS(.v16),
    .macOS(.v15),
  ],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "BridgingWebView",
      targets: ["BridgingWebView"]),
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "BridgingWebView"),
    .testTarget(
      name: "BridgingWebViewTests",
      dependencies: ["BridgingWebView"]
    ),
  ],
  swiftLanguageModes: [.v6]
)

