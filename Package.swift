// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "pana",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "pana",
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
            ]
        )
    ]
)
