#!/bin/bash

# Script to fix the menu bar icon for NetworkInfo

set -e  # Exit immediately if a command exits with a non-zero status

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${BASE_DIR}/Sources/NetworkInfo"
RESOURCES_DIR="${SOURCE_DIR}/Resources"
TEMP_DIR="${BASE_DIR}/.tmp_icons"

# Create a temporary directory for SVG files
mkdir -p "${TEMP_DIR}"
mkdir -p "${RESOURCES_DIR}"

echo "=== NetworkInfo Menu Bar Icon Fix ==="
echo "Creating an improved menu bar icon..."

# Check for required tools
if command -v convert >/dev/null 2>&1; then
    SVG_CONVERTER="imagemagick"
    echo "✅ Using ImageMagick for SVG conversion"
else
    echo "❌ ImageMagick not found."
    echo "Please install with: brew install imagemagick"
    exit 1
fi

# Create the improved menu bar icon SVG
cat > "${TEMP_DIR}/menu-icon.svg" << 'EOL'
<svg viewBox="0 0 22 22" xmlns="http://www.w3.org/2000/svg">
  <!-- Simple network icon for menu bar - adjusted for better visibility -->
  <circle cx="6" cy="6" r="2.5" fill="black"/>
  <circle cx="16" cy="6" r="2.5" fill="black"/>
  <circle cx="6" cy="16" r="2.5" fill="black"/>
  <circle cx="16" cy="16" r="2.5" fill="black"/>
  <circle cx="11" cy="11" r="3" fill="black"/>
  
  <!-- Connection lines - thicker for better visibility -->
  <line x1="6" y1="6" x2="11" y2="11" stroke="black" stroke-width="1.5"/>
  <line x1="16" y1="6" x2="11" y2="11" stroke="black" stroke-width="1.5"/>
  <line x1="6" y1="16" x2="11" y2="11" stroke="black" stroke-width="1.5"/>
  <line x1="16" y1="16" x2="11" y2="11" stroke="black" stroke-width="1.5"/>
</svg>
EOL

# Convert the SVG to PNG
echo "Converting menu bar icon..."
convert -background none "${TEMP_DIR}/menu-icon.svg" "${RESOURCES_DIR}/menu-icon.png"
convert -background none -resize "44x44" "${TEMP_DIR}/menu-icon.svg" "${RESOURCES_DIR}/menu-icon@2x.png"
echo "✅ Menu bar icon conversion complete"

# Clean up temporary files
rm -rf "${TEMP_DIR}"

echo "Recompiling the application..."
swift build -c release
echo "✅ Build complete!"

echo "Copying app to NetworkInfo.app..."
cp -Rf .build/release/NetworkInfo NetworkInfo.app/Contents/MacOS/NetworkInfo
echo "✅ Done! NetworkInfo.app has been updated."
echo "You can now run the application with: open NetworkInfo.app"
