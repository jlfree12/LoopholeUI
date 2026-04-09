// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "LoopholeUI",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "LoopholeUI", targets: ["LoopholeUI"])
    ],
    targets: [
        .executableTarget(
            name: "LoopholeUI",
            path: "Sources/LoopholeUI"
        )
    ]
)
