#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="LumiTerm"
DIST_DIR="dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"

echo "==> Building release..."
swift build -c release

echo "==> Assembling .app bundle..."
rm -rf "$DIST_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"

# Binary
cp ".build/release/$APP_NAME" "$APP_DIR/Contents/MacOS/"

# Resource bundle (at .app top level for SPM Bundle.module compatibility)
cp -R ".build/release/${APP_NAME}_${APP_NAME}.bundle" "$APP_DIR/"

# Info.plist
cp Info.plist "$APP_DIR/Contents/"

echo "==> Creating zip..."
cd "$DIST_DIR"
zip -r -q "$APP_NAME-macos.zip" "$APP_NAME.app"
cd ..

echo ""
echo "Done! Output:"
echo "  $DIST_DIR/$APP_NAME.app"
echo "  $DIST_DIR/$APP_NAME-macos.zip"
echo ""
echo "To test: open $DIST_DIR/$APP_NAME.app"
echo "To release: gh release create v1.5.0 $DIST_DIR/$APP_NAME-macos.zip --title '$APP_NAME v1.5.0'"
