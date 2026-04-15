#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="LumiTerm"
DIST_DIR="dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
BUNDLE_NAME="${APP_NAME}_${APP_NAME}.bundle"

# Read version from Info.plist
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist)
echo "==> Version: $VERSION"

echo "==> Building universal binary (arm64 + x86_64)..."
swift build -c release --arch arm64 --arch x86_64

echo "==> Assembling .app bundle..."
rm -rf "$DIST_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Binary
cp ".build/apple/Products/Release/$APP_NAME" "$APP_DIR/Contents/MacOS/"

# Resource bundle in standard location + top-level symlink for SPM Bundle.module
cp -R ".build/apple/Products/Release/$BUNDLE_NAME" "$APP_DIR/Contents/Resources/"
ln -s "Contents/Resources/$BUNDLE_NAME" "$APP_DIR/$BUNDLE_NAME"

# Info.plist
cp Info.plist "$APP_DIR/Contents/"

# App icon
if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns "$APP_DIR/Contents/Resources/"
fi

echo "==> Ad-hoc code signing..."
# Remove top-level symlink before signing (unsealed content), re-add after
rm -f "$APP_DIR/$BUNDLE_NAME"
codesign --force --deep --sign - "$APP_DIR"
ln -s "Contents/Resources/$BUNDLE_NAME" "$APP_DIR/$BUNDLE_NAME"

echo "==> Creating zip..."
cd "$DIST_DIR"
zip -r -q -y "$APP_NAME-macos.zip" "$APP_NAME.app"
cd ..

echo ""
echo "Done! Output:"
echo "  $DIST_DIR/$APP_NAME.app"
echo "  $DIST_DIR/$APP_NAME-macos.zip"
echo ""
echo "To test: open $DIST_DIR/$APP_NAME.app"
echo "To release: gh release create v$VERSION $DIST_DIR/$APP_NAME-macos.zip --title '$APP_NAME v$VERSION'"
