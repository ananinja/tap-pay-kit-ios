// swift-tools-version: 5.9
import PackageDescription

let frameworks = [
    "goSellSDK",
    "EditableTextInsetsTextFieldV2",
    "SwiftyRSA",
    "TapAdditionsKitV2",
    "TapApplicationV2",
    "TapBundleLocalizationV2",
    "TapCardVlidatorKit_iOS",
    "TapEditableViewV2",
    "TapFontsKitV2",
    "TapGLKitV2",
    "TapKeychainV2",
    "TapNetworkManagerV2",
    "TapNibViewV2",
    "TapResponderChainInputViewV2",
    "TapSearchViewV2",
    "TapSwiftFixesV2",
    "TapVisualEffectViewV2",
]

let package = Package(
    name: "TapPayKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "TapPayKit", targets: frameworks),
    ],
    targets: frameworks.map { .binaryTarget(name: $0, path: "Frameworks/\($0).xcframework.zip") }
)
