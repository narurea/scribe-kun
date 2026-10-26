#!/bin/sh
# Builds scribe-kun.app (Release, ad-hoc signed) and packs it into build/scribe-kun-<version>.dmg.
# Usage: ./scripts/make-dmg.sh [version]    (default: MARKETING_VERSION in project.yml)
set -eu
cd "$(dirname "$0")/.."

APP_NAME="scribe-kun"
VERSION="${1:-$(sed -n 's/^ *MARKETING_VERSION: *"\(.*\)"/\1/p' project.yml | head -n 1)}"
BUILD_DIR="build"
DERIVED_DATA="$BUILD_DIR/DerivedData"
STAGING="$BUILD_DIR/dmg"
DMG="$BUILD_DIR/$APP_NAME-$VERSION.dmg"

./scripts/bootstrap.sh

xcodebuild \
    -project Transcribe.xcodeproj \
    -scheme Transcribe \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$DERIVED_DATA" \
    MARKETING_VERSION="$VERSION" \
    build

APP="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
codesign --verify --deep --strict "$APP"

# The DMG holds the app and a shortcut to /Applications to drag it onto.
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
ditto "$APP" "$STAGING/$APP_NAME.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG"
rm -rf "$STAGING"

echo "DMG を作成しました: $DMG"
