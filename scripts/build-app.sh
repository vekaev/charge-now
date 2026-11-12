#!/usr/bin/env bash
# Builds Charge Now (universal: Apple Silicon + Intel) and packages dist/ChargeNow-mac.dmg.
# Needs only the Xcode Command Line Tools: the sources are compiled with swiftc, there is no Xcode project.
#   scripts/build-app.sh            build the app and the .dmg
#   scripts/build-app.sh --native   this Mac's architecture only, no .dmg (what install-mac.sh uses)
#   scripts/build-app.sh --install  also install to ~/Applications and launch
set -euo pipefail
cd "$(dirname "$0")/.."

NAME="Charge Now"
MODULE=ChargeNow
MIN_MACOS=13.0
APP="build/$NAME.app"

compile() {  # compile <arch>: one slice of the app
  swiftc -O -swift-version 5 -target "$1-apple-macos$MIN_MACOS" -module-name "$MODULE" \
    App/*.swift Core/*.swift -o "build/$MODULE-$1"
}

mkdir -p build
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
if [[ "${1:-}" == "--native" ]]; then
  compile "$(uname -m)"
  cp "build/$MODULE-$(uname -m)" "$APP/Contents/MacOS/$MODULE"
else
  compile arm64
  compile x86_64
  lipo -create "build/$MODULE-arm64" "build/$MODULE-x86_64" -output "$APP/Contents/MacOS/$MODULE"
fi
cp App/Info.plist "$APP/Contents/Info.plist"
cp App/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Signed with a real certificate when there is one (scripts/signing.sh), ad-hoc otherwise.
source scripts/signing.sh
codesign --force --sign "$(sign_identity)" "$APP"

[[ "${1:-}" == "--native" ]] && { echo "Built $APP"; exit 0; }

rm -rf dist && mkdir -p dist/dmg
cp -R "$APP" "dist/dmg/$NAME.app"
ln -s /Applications dist/dmg/Applications
hdiutil create -quiet -volname "$NAME" -srcfolder dist/dmg -ov -format UDZO "dist/$MODULE-mac.dmg"
rm -rf dist/dmg
echo "Built dist/$MODULE-mac.dmg"

[[ "${1:-}" == "--install" ]] && scripts/install-mac.sh || true
