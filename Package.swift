// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "CopyGlass", platforms: [.macOS(.v14)], products: [.executable(name: "CopyGlass", targets: ["CopyGlass"])], targets: [.executableTarget(name: "CopyGlass", resources: [.process("Resources")])])
