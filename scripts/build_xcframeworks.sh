#!/usr/bin/env bash
set -euo pipefail

GOSELL_VERSION="${GOSELL_VERSION:-2.3.43}"
DEPLOYMENT_TARGET="${DEPLOYMENT_TARGET:-17.0}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$REPO_ROOT/Frameworks"
WORK_DIR="$(mktemp -d)"
STAGING_DIR="$WORK_DIR/xcframeworks"
trap 'rm -rf "$WORK_DIR"' EXIT

cd "$WORK_DIR"

cat > Podfile <<EOF
platform :ios, '$DEPLOYMENT_TARGET'
install! 'cocoapods', :integrate_targets => false
use_frameworks!
target 'TapPay' do
  pod 'goSellSDK', '$GOSELL_VERSION'
end
EOF

ruby -rxcodeproj -e '
  project = Xcodeproj::Project.new("TapPay.xcodeproj")
  project.new_target(:application, "TapPay", :ios, ARGV[0])
  project.save
' "$DEPLOYMENT_TARGET"

pod install

find Pods -name '*.swift' -exec sed -i '' -E \
  's/^import[[:space:]]+(struct|class|enum|protocol|func|var|let|typealias)[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)\.[^.[:space:]]+\..*$/import \2/' {} +

for SLICE in "iphoneos:arm64" "iphonesimulator:arm64 x86_64"; do
  IFS=: read -r SDK ARCHS <<< "$SLICE"
  xcodebuild build \
    -project Pods/Pods.xcodeproj \
    -target Pods-TapPay \
    -configuration Release \
    -sdk "$SDK" \
    SYMROOT="$WORK_DIR/build" \
    OBJROOT="$WORK_DIR/obj" \
    ARCHS="$ARCHS" \
    EXCLUDED_ARCHS= \
    ONLY_ACTIVE_ARCH=NO \
    IPHONEOS_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    SKIP_INSTALL=NO \
    DEBUG_INFORMATION_FORMAT=dwarf-with-dsym \
    OTHER_SWIFT_FLAGS='$(inherited) -Xfrontend -alias-module-names-in-module-interface' \
    > "$WORK_DIR/build-$SDK.log" 2>&1 \
    || { grep -E "error:" "$WORK_DIR/build-$SDK.log" | sort -u; exit 1; }
done

mkdir -p "$STAGING_DIR"

for DEVICE_FRAMEWORK in "$WORK_DIR"/build/Release-iphoneos/*/*.framework; do
  NAME="$(basename "$DEVICE_FRAMEWORK" .framework)"
  POD_DIR="$(basename "$(dirname "$DEVICE_FRAMEWORK")")"
  SIM_FRAMEWORK="$WORK_DIR/build/Release-iphonesimulator/$POD_DIR/$NAME.framework"
  xcodebuild -create-xcframework \
    -framework "$DEVICE_FRAMEWORK" -debug-symbols "$DEVICE_FRAMEWORK.dSYM" \
    -framework "$SIM_FRAMEWORK" -debug-symbols "$SIM_FRAMEWORK.dSYM" \
    -output "$STAGING_DIR/$NAME.xcframework"
done

find "$STAGING_DIR/goSellSDK.xcframework" -name '*.swiftinterface' -exec \
  sed -i '' -E '/^extension [[:alnum:]_:.]*PayButton : [[:alnum:]_:.]*ClassProtocol [{][}]$/d' {} +

echo 'import goSellSDK' > "$WORK_DIR/probe.swift"
for SLICE in "ios-arm64:iphoneos:arm64-apple-ios$DEPLOYMENT_TARGET" \
             "ios-arm64_x86_64-simulator:iphonesimulator:arm64-apple-ios$DEPLOYMENT_TARGET-simulator"; do
  IFS=: read -r DIR SDK TRIPLE <<< "$SLICE"
  SEARCH_PATHS=()
  for XCFRAMEWORK in "$STAGING_DIR"/*.xcframework; do
    SEARCH_PATHS+=(-F "$XCFRAMEWORK/$DIR")
  done
  xcrun -sdk "$SDK" swiftc -typecheck -target "$TRIPLE" "${SEARCH_PATHS[@]}" \
    -module-cache-path "$WORK_DIR/module-cache-$SDK" "$WORK_DIR/probe.swift"
done

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
for XCFRAMEWORK in "$STAGING_DIR"/*.xcframework; do
  ditto -c -k --keepParent "$XCFRAMEWORK" "$OUTPUT_DIR/$(basename "$XCFRAMEWORK").zip"
done

ls -lh "$OUTPUT_DIR"
