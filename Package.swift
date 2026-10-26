// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Vernier",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "VernierCore", targets: ["VernierCore"]),
        .executable(name: "Vernier", targets: ["VernierApp"])
    ],
    targets: [
        .systemLibrary(name: "CSQLite"),
        .target(name: "VernierCore", dependencies: ["CSQLite"]),
        .executableTarget(name: "VernierApp", dependencies: ["VernierCore"], resources: [.copy("Resources/Brand.plist")]),
        .target(name: "VernierChecks", dependencies: ["VernierCore", "CSQLite"], path: "Tests/Support"),
        .executableTarget(name: "VernierCoreChecks", dependencies: ["VernierChecks", "VernierCore"], path: "Tests/CoreChecks"),
        .testTarget(name: "VernierCoreTests", dependencies: ["VernierChecks"])
    ]
)
