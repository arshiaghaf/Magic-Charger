#!/bin/sh
set -eu
cd "$(dirname "$0")"
if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode.app/Contents/Developer ]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
CONFIGURATION="${CONFIGURATION:-debug}"
case "$CONFIGURATION" in debug|release) ;; *) echo "CONFIGURATION must be debug or release" >&2; exit 2 ;; esac
APP_VERSION="$(cat VERSION)"
APP_BUILD="${APP_BUILD:-$(cat BUILD_NUMBER)}"
if ! printf '%s\n' "$APP_VERSION" | LC_ALL=C grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "VERSION must contain a numeric major.minor.patch version" >&2
    exit 2
fi
if ! printf '%s\n' "$APP_BUILD" | LC_ALL=C grep -Eq '^[1-9][0-9]*$'; then
    echo "APP_BUILD must be a positive integer" >&2
    exit 2
fi
swift build --configuration "$CONFIGURATION"
BIN_DIR="$(swift build --configuration "$CONFIGURATION" --show-bin-path)"
APP="build/Magic Charger.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/MagicCharger" "$APP/Contents/MacOS/MagicCharger"
cp LICENSE "$APP/Contents/Resources/LICENSE"
cp assets/MagicCharger.icns "$APP/Contents/Resources/MagicCharger.icns"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>co.arshia.magiccharger</string><key>CFBundleName</key><string>Magic Charger</string><key>CFBundleExecutable</key><string>MagicCharger</string><key>CFBundlePackageType</key><string>APPL</string><key>CFBundleIconFile</key><string>MagicCharger</string><key>CFBundleVersion</key><string>$APP_BUILD</string><key>CFBundleShortVersionString</key><string>$APP_VERSION</string><key>MagicChargerBuildConfiguration</key><string>$CONFIGURATION</string><key>LSMinimumSystemVersion</key><string>14.0</string><key>NSHumanReadableCopyright</key><string>Copyright © 2026 Arshia Ghaf. MIT License.</string><key>LSUIElement</key><true/></dict></plist>
PLIST
codesign --force --sign - "$APP"
