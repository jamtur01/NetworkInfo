#!/bin/bash

# Script to build NetworkInfo as a proper macOS app bundle

# Set variables
WORKSPACE_DIR="/Users/james/src/NetworkInfo"
APP_NAME="NetworkInfo.app"
APP_PATH="$WORKSPACE_DIR/$APP_NAME"
CONTENTS_PATH="$APP_PATH/Contents"
MACOS_PATH="$CONTENTS_PATH/MacOS"
RESOURCES_PATH="$CONTENTS_PATH/Resources"

# Clean up previous app
rm -rf "$APP_PATH"

# Build with swift
echo "Building executable..."
cd "$WORKSPACE_DIR"
swift build -c release

# Check if build succeeded
if [ ! -f ".build/release/NetworkInfo" ]; then
    echo "Build failed! Executable not found."
    exit 1
fi

# Create app directory structure
echo "Creating app bundle structure..."
mkdir -p "$MACOS_PATH"
mkdir -p "$RESOURCES_PATH"

# Copy executable
echo "Copying executable..."
cp ".build/release/NetworkInfo" "$MACOS_PATH/"
chmod +x "$MACOS_PATH/NetworkInfo"

# Create Info.plist
echo "Creating Info.plist..."
cat > "$CONTENTS_PATH/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>NetworkInfo</string>
    <key>CFBundleIconFile</key>
    <string></string>
    <key>CFBundleIdentifier</key>
    <string>com.jamtur01.NetworkInfo</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>NetworkInfo</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2025 James Turnbull. All rights reserved.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

# Create PkgInfo
echo "Creating PkgInfo..."
echo "APPL????" > "$CONTENTS_PATH/PkgInfo"

# Verify bundle structure
echo "Verifying app bundle..."
ls -la "$APP_PATH"
ls -la "$CONTENTS_PATH"
ls -la "$MACOS_PATH"

echo ""
echo "App bundle created at $APP_PATH"
echo "You can run it with: open $APP_PATH"
