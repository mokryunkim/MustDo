#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="MustDo"
VERSION="0.1.0"
APP_BUNDLE="$ROOT_DIR/dist/${APP_NAME}.app"
RELEASE_DIR="$ROOT_DIR/dist/release"
DMG_PATH="$RELEASE_DIR/${APP_NAME}-${VERSION}.dmg"
PKG_PATH="$RELEASE_DIR/${APP_NAME}-${VERSION}.pkg"

bash "$ROOT_DIR/scripts/make_app_bundle.sh"

mkdir -p "$RELEASE_DIR"
rm -f "$DMG_PATH" "$PKG_PATH"

hdiutil create -volname "$APP_NAME" -srcfolder "$APP_BUNDLE" -ov -format UDZO "$DMG_PATH"
pkgbuild --component "$APP_BUNDLE" --install-location "/Applications" "$PKG_PATH"

echo "Release artifacts:"
echo "- $DMG_PATH"
echo "- $PKG_PATH"
