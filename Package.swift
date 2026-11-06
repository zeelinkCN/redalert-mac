// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RedAlertMac",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "RedAlertCore", targets: ["RedAlertCore"]),
        .executable(name: "RedAlertMac", targets: ["RedAlertMac"]),
        .executable(name: "redalertctl", targets: ["RedAlertCLI"])
    ],
    targets: [
        .target(name: "RedAlertCore"),
        .executableTarget(name: "RedAlertMac", dependencies: ["RedAlertCore"],
                          resources: [.copy("Resources/Compatibility"), .copy("Resources/Artwork"), .copy("Resources/Tools")]),
        .executableTarget(name: "RedAlertCLI", dependencies: ["RedAlertCore"]),
        .executableTarget(name: "RedAlertChecks", dependencies: ["RedAlertCore"], path: "Tests/RedAlertCoreTests")
    ],
    swiftLanguageModes: [.v5]
)
