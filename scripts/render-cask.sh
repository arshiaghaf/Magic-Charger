#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

if [ "$#" -ne 3 ]; then
    echo "Usage: sh scripts/render-cask.sh VERSION PUBLISHED_DMG_FILE RELEASE_ASSET_URL" >&2
    exit 2
fi
VERSION="$1"
ASSET="$2"
URL="$3"
DMG="Magic-Charger-$VERSION.dmg"

if [ "$VERSION" != "$(cat VERSION)" ] ||
   ! printf '%s\n' "$VERSION" | LC_ALL=C grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' ||
   [ ! -f "$ASSET" ] || [ "$(basename "$ASSET")" != "$DMG" ] ||
   ! printf '%s\n' "$URL" | LC_ALL=C grep -Eq '^https://[A-Za-z0-9._~:/?=&%+@-]+$'; then
    echo "Expected the checkout version, the published DMG file, and its real HTTPS asset URL" >&2
    exit 2
fi
case "$URL" in
    */"$DMG"|*/"$DMG"\?*) ;;
    *) echo "URL must name the same versioned DMG asset" >&2; exit 2 ;;
esac
SHA256="$(shasum -a 256 "$ASSET" | awk '{print $1}')"

cat <<CASK
cask "magic-charger" do
  version "$VERSION"
  sha256 "$SHA256"

  url "$URL"
  name "Magic Charger"
  desc "Charging notifications for Magic Keyboard and Magic Mouse"
  homepage "https://github.com/arshiaghaf/Magic-Charger"

  depends_on macos: :sonoma
  app "Magic Charger.app"
end
CASK
