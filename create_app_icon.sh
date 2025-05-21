#!/bin/bash

# Script to create app icon and menu bar icon using system icons

set -e  # Exit immediately if a command exits with a non-zero status

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOURCES_DIR="${BASE_DIR}/NetworkInfo.app/Contents/Resources"

echo "=== Creating NetworkInfo App Icon ==="

# Check for required tools
if ! command -v sips &> /dev/null || ! command -v iconutil &> /dev/null; then
    echo "⚠️ Required tools (sips, iconutil) not found. This script requires macOS."
    exit 1
fi

# Create temporary icon directory
ICON_DIR=$(mktemp -d)
ICONSET_DIR="${ICON_DIR}/AppIcon.iconset"
mkdir -p "${ICONSET_DIR}"

echo "Creating app icon using SF Symbols..."

# Create a basic app icon - blue circle with network icon
cat > "${ICON_DIR}/app-icon.svg" << 'EOL'
<svg width="1024" height="1024" xmlns="http://www.w3.org/2000/svg">
  <!-- Blue background -->
  <circle cx="512" cy="512" r="450" fill="#0066CC"/>
  
  <!-- Network nodes and connections in white -->
  <circle cx="512" cy="512" r="80" fill="white"/>
  <circle cx="300" cy="300" r="60" fill="white"/>
  <circle cx="724" cy="300" r="60" fill="white"/>
  <circle cx="300" cy="724" r="60" fill="white"/>
  <circle cx="724" cy="724" r="60" fill="white"/>
  
  <line x1="300" y1="300" x2="512" y2="512" stroke="white" stroke-width="30"/>
  <line x1="724" y1="300" x2="512" y2="512" stroke="white" stroke-width="30"/>
  <line x1="300" y1="724" x2="512" y2="512" stroke="white" stroke-width="30"/>
  <line x1="724" y1="724" x2="512" y2="512" stroke="white" stroke-width="30"/>
</svg>
EOL

# Use sips to convert the SVG to PNG at various required sizes
ICON_SIZES=(16 32 64 128 256 512 1024)

for size in "${ICON_SIZES[@]}"; do
    # Create the PNG at this size
    if command -v rsvg-convert &> /dev/null; then
        rsvg-convert -w $size -h $size "${ICON_DIR}/app-icon.svg" -o "${ICONSET_DIR}/icon_${size}x${size}.png"
    else
        # Fallback to sips (less ideal for SVG conversion)
        sips -s format png "${ICON_DIR}/app-icon.svg" --out "${ICONSET_DIR}/temp.png" &> /dev/null
        sips -z $size $size "${ICONSET_DIR}/temp.png" --out "${ICONSET_DIR}/icon_${size}x${size}.png" &> /dev/null
        rm "${ICONSET_DIR}/temp.png"
    fi
    
    # For 2x versions
    if [ $size -le 512 ]; then
        double_size=$((size * 2))
        if command -v rsvg-convert &> /dev/null; then
            rsvg-convert -w $double_size -h $double_size "${ICON_DIR}/app-icon.svg" -o "${ICONSET_DIR}/icon_${size}x${size}@2x.png"
        else
            sips -s format png "${ICON_DIR}/app-icon.svg" --out "${ICONSET_DIR}/temp.png" &> /dev/null
            sips -z $double_size $double_size "${ICONSET_DIR}/temp.png" --out "${ICONSET_DIR}/icon_${size}x${size}@2x.png" &> /dev/null
            rm "${ICONSET_DIR}/temp.png"
        fi
    fi
done

# Convert to .icns file
iconutil -c icns "${ICONSET_DIR}" -o "${RESOURCES_DIR}/AppIcon.icns"
echo "✅ Created AppIcon.icns in Resources directory"

# Clean up
rm -rf "${ICON_DIR}"

echo "✨ App icon created successfully!"
echo "🔄 Run the application with: open NetworkInfo.app"
