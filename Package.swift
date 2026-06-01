// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "Portwhore",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .executable(
      name: "Portwhore",
      targets: ["Portwhore"]
    )
  ],
  targets: [
    .executableTarget(
      name: "Portwhore"
    ),
    .testTarget(
      name: "PortwhoreTests",
      dependencies: ["Portwhore"]
    )
  ]
)
