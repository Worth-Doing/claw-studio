#!/bin/bash
set -e

echo "=== Claw Studio Build Script ==="
echo ""

# Configuration
APP_NAME="Claw Studio"
BUNDLE_NAME="ClawStudio"
BUILD_DIR=".build"
APP_BUNDLE="${APP_NAME}.app"

# Step 1: Build
echo "[1/4] Building Swift package..."
swift build -c release 2>&1

echo "[2/4] Creating app bundle..."

# Clean previous bundle
rm -rf "${APP_BUNDLE}"

# Create bundle structure
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Step 3: Copy binary
echo "[3/4] Copying binary..."
cp "${BUILD_DIR}/release/${BUNDLE_NAME}" "${APP_BUNDLE}/Contents/MacOS/${BUNDLE_NAME}"

# Step 4: Copy Info.plist
echo "[4/4] Configuring bundle..."
cp Resources/Info.plist "${APP_BUNDLE}/Contents/Info.plist"

# Create PkgInfo
echo -n "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"

# Create entitlements for network + process spawning
cat > /tmp/clawstudio-entitlements.plist << 'ENTITLEMENTS'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
ENTITLEMENTS

# Sign the app (ad-hoc)
codesign --force --deep --sign - --entitlements /tmp/clawstudio-entitlements.plist "${APP_BUNDLE}" 2>/dev/null || true

echo ""
echo "=== Build Complete ==="
echo "App bundle: $(pwd)/${APP_BUNDLE}"
echo ""
echo "To run:  open '${APP_BUNDLE}'"
echo "To move: cp -R '${APP_BUNDLE}' /Applications/"
