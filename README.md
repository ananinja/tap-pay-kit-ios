# tap-pay-kit-ios

Tap Payments' [goSellSDK](https://github.com/Tap-Payments/goSellSDK-iOS) and its dependencies, prebuilt as XCFrameworks and served as a Swift package (`TapPayKit`). Tap doesn't ship SPM support, so this repo builds it for us.

## Use it

```swift
.package(url: "https://github.com/ananinja/tap-pay-kit-ios.git", exact: "2.3.43")
```

Link the `TapPayKit` product and `import goSellSDK`. Tags match the goSellSDK version.

## Build a new version

Run the **Build XCFrameworks** workflow with the goSellSDK version. It runs only when triggered, builds with the runner image's default (latest released) Xcode, commits `Frameworks/` on top of `main`, and pushes only the version tag (`main` requires signed commits, so the frameworks live under the tags). Consumers need that Xcode or newer, since older compilers can't read newer module interfaces.

Locally (needs CocoaPods): `GOSELL_VERSION=2.3.43 scripts/build_xcframeworks.sh`

The script patches two goSellSDK quirks that otherwise break the generated `.swiftinterface` files, then type-checks `import goSellSDK` on both slices before zipping.
