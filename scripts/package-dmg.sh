#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

APP="build/Magic Charger.app"
if [ ! -d "$APP" ]; then
    echo "Build the app first with CONFIGURATION=release sh build-app.sh" >&2
    exit 2
fi

VERSION="$(cat VERSION)"
BUILD="${APP_BUILD:-$(cat BUILD_NUMBER)}"
PLIST="$APP/Contents/Info.plist"
if [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST")" != "co.arshia.magiccharger" ] ||
   [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")" != "$VERSION" ] ||
   [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")" != "$BUILD" ]; then
    echo "Bundle identity/version does not match this checkout; rebuild before packaging" >&2
    exit 2
fi

codesign --verify --strict "$APP"
cmp LICENSE "$APP/Contents/Resources/LICENSE"
ARCHITECTURES="$(lipo -archs "$APP/Contents/MacOS/MagicCharger")"
if [ "$ARCHITECTURES" != arm64 ]; then
    echo "Release DMG currently supports arm64 only; found: $ARCHITECTURES" >&2
    exit 2
fi

mkdir -p dist
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/magic-charger-dmg.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT HUP INT TERM
ditto "$APP" "$STAGING/Magic Charger.app"
ln -s /Applications "$STAGING/Applications"
cp assets/MagicCharger.icns "$STAGING/.VolumeIcon.icns"
if DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" xcrun --find SetFile >/dev/null 2>&1; then
    DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" xcrun SetFile -a C "$STAGING"
fi

DMG="Magic-Charger-$VERSION.dmg"
if [ -e "dist/$DMG" ]; then
    echo "dist/$DMG already exists; remove it explicitly before rebuilding" >&2
    exit 2
fi
hdiutil create -quiet -volname "Magic Charger $VERSION" -srcfolder "$STAGING" \
    -fs HFS+ -format UDZO "dist/$DMG"
hdiutil verify -quiet "dist/$DMG"
(cd dist && shasum -a 256 "$DMG" > SHA256SUMS)
echo "Created dist/$DMG and dist/SHA256SUMS (arm64 only; ad-hoc signed; not notarized)"
