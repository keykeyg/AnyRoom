// swift-tools-version: 6.0
// PlayStationKit: PS4/PS5 Remote Play (and later PlayStation cloud) for Anyroom.
//
// Chiaki      prebuilt chiaki-lib + dependencies for tvOS (Pylux fork of chiaki-ng, AGPL-3.0),
//             built by .github/workflows/chiaki-tvos.yml from Tools/chiaki-build/.
// ChiakiBridge Objective-C bridge to chiaki-lib, from Pylux's iOS app (ios/Pylux/Bridge, AGPL-3.0).
// PlayStationKit Swift services and SwiftUI views. Stream session, input and feedback code comes from
//             Pylux's iOS app (AGPL-3.0), adapted for Apple TV.
import PackageDescription

let package = Package(
    name: "PlayStationKit",
    platforms: [.tvOS(.v17), .iOS(.v17)],
    products: [
        .library(name: "PlayStationKit", targets: ["PlayStationKit"]),
    ],
    targets: [
        .binaryTarget(
            name: "Chiaki",
            url: "https://github.com/keykeyg/AnyRoom/releases/download/chiaki-tvos-ca87a49-r7/Chiaki.xcframework.zip",
            checksum: "aabfbcd9715a7894778b56c147a4c74781f9cbeafbd9018d0fb1df8459efd9ff"
        ),
        .target(
            name: "ChiakiBridge",
            dependencies: ["Chiaki"],
            path: "Sources/ChiakiBridge",
            cSettings: [
                .define("CHIAKI_LIB_ENABLE_MBEDTLS", to: "1"),
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("VideoToolbox"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("Security"),
                .linkedFramework("SystemConfiguration"),
                .linkedFramework("CFNetwork"),
                .linkedLibrary("z"),
                .linkedLibrary("c++"),
                .linkedLibrary("resolv"),
            ]
        ),
        .target(
            name: "PlayStationKit",
            dependencies: ["ChiakiBridge"],
            path: "Sources/PlayStationKit",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
