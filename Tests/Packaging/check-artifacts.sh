#!/bin/sh
# Regression checks use only temporary fixtures and never launch an app.
set -eu
cd "$(dirname "$0")/../.."
ROOT="$PWD"
VERSION="$(cat VERSION)"
ASSET="$ROOT/dist/Magic-Charger-$VERSION.dmg"
test -f "$ASSET"
FIXTURES="$(mktemp -d "${TMPDIR:-/tmp}/magic-charger-packaging-check.XXXXXX")"
trap 'rm -rf "$FIXTURES"' EXIT HUP INT TERM

# A real release artifact renders its actual checksum and ARM-only requirement.
TEST_URL="https://example.invalid/Magic-Charger-$VERSION.dmg"
sh scripts/render-cask.sh "$VERSION" "$ASSET" "$TEST_URL" > "$FIXTURES/cask.rb"
EXPECTED_SHA="$(shasum -a 256 "$ASSET" | awk '{print $1}')"
grep -F "sha256 \"$EXPECTED_SHA\"" "$FIXTURES/cask.rb" >/dev/null
grep -F 'depends_on arch: :arm64' "$FIXTURES/cask.rb" >/dev/null

# A debug bundle must fail specifically at configuration validation, before signing.
DEBUG_ROOT="$FIXTURES/debug"
mkdir -p "$DEBUG_ROOT/scripts" "$DEBUG_ROOT/build/Magic Charger.app/Contents"
cp scripts/package-dmg.sh "$DEBUG_ROOT/scripts/"
cp VERSION BUILD_NUMBER "$DEBUG_ROOT/"
cp 'build/Magic Charger.app/Contents/Info.plist' "$DEBUG_ROOT/build/Magic Charger.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :MagicChargerBuildConfiguration debug' "$DEBUG_ROOT/build/Magic Charger.app/Contents/Info.plist"
if sh "$DEBUG_ROOT/scripts/package-dmg.sh" > "$FIXTURES/debug.log" 2>&1; then
    echo 'FAIL: debug bundle was accepted' >&2; exit 1
fi
grep -F 'Packaging requires a release bundle' "$FIXTURES/debug.log" >/dev/null

# A plausible filename/architecture is insufficient when mounted metadata differs.
for FIELD in CFBundleIdentifier CFBundleShortVersionString; do
    CASE_ROOT="$FIXTURES/$FIELD"
    mkdir -p "$CASE_ROOT/staging"
    ditto 'build/Magic Charger.app' "$CASE_ROOT/staging/Magic Charger.app"
    /usr/libexec/PlistBuddy -c "Set :$FIELD invalid-fixture" "$CASE_ROOT/staging/Magic Charger.app/Contents/Info.plist"
    BAD_ASSET="$CASE_ROOT/Magic-Charger-$VERSION.dmg"
    hdiutil create -quiet -volname 'Magic Charger validation fixture' -srcfolder "$CASE_ROOT/staging" -fs HFS+ -format UDZO "$BAD_ASSET"
    if sh scripts/render-cask.sh "$VERSION" "$BAD_ASSET" "$TEST_URL" > "$CASE_ROOT/result.log" 2>&1; then
        echo "FAIL: mismatched $FIELD was accepted" >&2; exit 1
    fi
    grep -F 'Published DMG bundle identity/version does not match' "$CASE_ROOT/result.log" >/dev/null
done
printf '%s\n' 'Packaging regressions passed: release checksum, ARM guard, debug rejection, mounted identity/version rejection.'
