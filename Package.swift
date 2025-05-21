// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "awm",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "awm",
            dependencies: [
                .product(name: "Collections", package: "swift-collections")
            ],
            swiftSettings: [
                .unsafeFlags(
                    [
                        "-Ounchecked",
                        "-wmo",
                        "-disable-actor-data-race-checks",
                        "-disable-autolinking-runtime-compatibility-concurrency",
                        "-disable-autolinking-runtime-compatibility-dynamic-replacements",
                        "-disable-autolinking-runtime-compatibility",
                        "-disable-dynamic-actor-isolation",
                        "-disable-incremental-imports",
                        "-disable-sandbox",
                        "-gnone",
                        "-remove-runtime-asserts",
                    ], .when(configuration: .release)
                )
            ],
        )
    ]
)
