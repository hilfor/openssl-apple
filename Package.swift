// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "openssl-apple",
    // macOS 14 is FMake's own floor from v1.0.0 on; SwiftPM refuses to resolve a
    // dependency whose minimum platform is above the consumer's.
    platforms: [.macOS("14")],
    // Package.resolved is committed alongside this file. `from:` is an open 1.x
    // range, and a release tag can move -- hilfor/FMake's own v1.0.0 already
    // did -- so the range alone would let CI and a developer build this
    // artifact against different revisions of the build tool.
    dependencies: [
        .package(url: "https://github.com/hilfor/FMake", from : "1.0.0"),
    //    .package(path: "../FMake")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "openssl-apple",
            dependencies: ["FMake"]),
    ]
)
