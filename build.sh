#!/bin/bash

# NetworkInfo Build Script
# Builds the NetworkInfo app bundle with proper structure

set -e  # Exit immediately if a command exits with a non-zero status

# Set variables
WORKSPACE_DIR="$(pwd)"
APP_NAME="NetworkInfo.app"
APP_PATH="$WORKSPACE_DIR/$APP_NAME"
CONTENTS_PATH="$APP_PATH/Contents"
MACOS_PATH="$CONTENTS_PATH/MacOS"
RESOURCES_PATH="$CONTENTS_PATH/Resources"

echo "=== NetworkInfo Build Script ==="
echo "Working directory: $WORKSPACE_DIR"

# Extract version from Version.swift
echo "Extracting version information..."
VERSION=$(grep -m 1 "static let version = " Sources/NetworkInfo/Version.swift | cut -d '"' -f 2)
BUILD=$(grep -m 1 "static let build = " Sources/NetworkInfo/Version.swift | cut -d '"' -f 2)
echo "Building NetworkInfo version $VERSION (build $BUILD)..."

# Clean previous build
echo "Cleaning previous build..."
rm -rf "$APP_PATH"
swift package clean

# Build with Swift
echo "Building executable..."
swift build -c release

# Check if build succeeded
if [ ! -f ".build/release/NetworkInfo" ]; then
    echo "❌ Build failed! Executable not found."
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

# Create Info.plist with version info
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
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.jamtur01.NetworkInfo</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>NetworkInfo</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD</string>
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

# Copy resources if they exist
if [ -d "Sources/NetworkInfo/Resources" ]; then
    echo "Copying resources..."
    cp -r Sources/NetworkInfo/Resources/* "$RESOURCES_PATH/" 2>/dev/null || true
fi

# Copy icon if it exists
if [ -f "Sources/NetworkInfo/Resources/AppIcon.icns" ]; then
    echo "Copying app icon..."
    cp "Sources/NetworkInfo/Resources/AppIcon.icns" "$RESOURCES_PATH/"
fi

echo ""
echo "✅ Build complete!"
echo "📦 App bundle created at: $APP_NAME"
echo "🚀 Run with: open $APP_NAME"
echo ""
echo "Optional commands:"
echo "  Test:    swift test"
echo "  Clean:   swift package clean"
echo "  Debug:   swift build"