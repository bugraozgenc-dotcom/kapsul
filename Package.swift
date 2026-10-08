// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CopyGlass",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "CopyGlass", targets: ["CopyGlass"])],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.0")],
    targets: [.executableTarget(
        name: "CopyGlass",
        dependencies: [.product(name: "Sparkle", package: "Sparkle")],
        resources: [.process("Resources")],
        linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
    )]
)
