#!/bin/bash

# Script to improve all icons for NetworkInfo

set -e  # Exit immediately if a command exits with a non-zero status

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${BASE_DIR}/Sources/NetworkInfo"
RESOURCES_DIR="${SOURCE_DIR}/Resources"
TEMP_DIR="${BASE_DIR}/.tmp_icons"

# Create a temporary directory for SVG files
mkdir -p "${TEMP_DIR}"
mkdir -p "${RESOURCES_DIR}"

echo "=== NetworkInfo Icon Improvement ==="
echo "Creating improved icons..."

# Check for required tools
if command -v convert >/dev/null 2>&1; then
    SVG_CONVERTER="imagemagick"
    echo "✅ Using ImageMagick for SVG conversion"
else
    echo "❌ ImageMagick not found."
    echo "Please install with: brew install imagemagick"
    exit 1
fi

# Function to convert SVG to PNG
convert_svg_to_png() {
    local svg_file=$1
    local output_file=$2
    local width=$3
    local height=$4
    
    echo "Converting: ${svg_file} to ${output_file} (${width}x${height})"
    convert -background none -resize "${width}x${height}" "${svg_file}" "${output_file}"
}

# Create improved menu bar icon
echo "Creating menu bar icon..."
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

# Create improved menu item icons
echo "Creating menu item icons..."

# Public IP Icon
cat > "${TEMP_DIR}/public-ip.svg" << 'EOL'
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <circle cx="12" cy="12" r="10" fill="none" stroke="black" stroke-width="1.8"/>
  <path d="M12,2 C6.48,2 2,6.48 2,12 C2,17.52 6.48,22 12,22 C17.52,22 22,17.52 22,12 C22,6.48 17.52,2 12,2 Z M3.7,12 C3.7,12 6,15 12,15 C18,15 20.3,12 20.3,12 C20.3,12 18,9 12,9 C6,9 3.7,12 3.7,12 Z" fill="black" fill-rule="evenodd" opacity="0.5"/>
  <circle cx="12" cy="12" r="3" fill="black"/>
</svg>
EOL# Local IP Icon
cat > "${TEMP_DIR}/local-ip.svg" << 'EOL'
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <rect x="4" y="4" width="16" height="12" rx="2" fill="none" stroke="black" stroke-width="1.8"/>
  <path d="M8,20 L16,20" stroke="black" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M12,16 L12,20" stroke="black" stroke-width="1.8" stroke-linecap="round"/>
  <circle cx="8" cy="9" r="1.5" fill="black"/>
  <circle cx="12" cy="9" r="1.5" fill="black"/>
  <circle cx="16" cy="9" r="1.5" fill="black"/>
</svg>
EOL

# SSID Icon
cat > "${TEMP_DIR}/ssid.svg" << 'EOL'
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path d="M4,12 C6.33,9.67 9.67,9 12,9 C14.33,9 17.67,9.67 20,12" stroke="black" stroke-width="1.8" stroke-linecap="round" fill="none"/>
  <path d="M7,15 C8.33,13.67 10.33,13 12,13 C13.67,13 15.67,13.67 17,15" stroke="black" stroke-width="1.8" stroke-linecap="round" fill="none"/>
  <circle cx="12" cy="18" r="2" fill="black"/>
</svg>
EOL

# DNS Icon
cat > "${TEMP_DIR}/dns.svg" << 'EOL'
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <rect x="3" y="5" width="18" height="14" rx="2" stroke="black" stroke-width="1.8" fill="none"/>
  <path d="M7,9 L17,9" stroke="black" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M7,13 L14,13" stroke="black" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M7,17 L12,17" stroke="black" stroke-width="1.8" stroke-linecap="round"/>
</svg>
EOL

# VPN Icon
cat > "${TEMP_DIR}/vpn.svg" << 'EOL'
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <circle cx="12" cy="12" r="9" stroke="black" stroke-width="1.8" fill="none"/>
  <path d="M12,3 C7.03,3 3,7.03 3,12 L21,12 C21,7.03 16.97,3 12,3 Z" fill="black" opacity="0.4"/>
  <rect x="9" y="10" width="6" height="8" rx="1" stroke="black" stroke-width="1.8" fill="none"/>
  <circle cx="12" cy="13" r="1" fill="black"/>
  <path d="M12,13 L12,16" stroke="black" stroke-width="1.8" stroke-linecap="round"/>
</svg>
EOL# Service Icon
cat > "${TEMP_DIR}/service.svg" << 'EOL'
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path d="M12,4 L12,8" stroke="black" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M16,6 L14,9.5" stroke="black" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M8,6 L10,9.5" stroke="black" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M4,12 L8,12" stroke="black" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M16,12 L20,12" stroke="black" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M6,17 L9.5,15" stroke="black" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M14.5,15 L18,17" stroke="black" stroke-width="1.8" stroke-linecap="round"/>
  <circle cx="12" cy="12" r="3" fill="black"/>
</svg>
EOL

# ISP Icon
cat > "${TEMP_DIR}/isp.svg" << 'EOL'
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path d="M4,6 L20,6 L20,18 L4,18 L4,6 Z" stroke="black" stroke-width="1.8" fill="none"/>
  <path d="M8,6 L8,18" stroke="black" stroke-width="1.8"/>
  <path d="M16,6 L16,18" stroke="black" stroke-width="1.8"/>
  <path d="M4,12 L20,12" stroke="black" stroke-width="1.8"/>
</svg>
EOL

# Location Icon
cat > "${TEMP_DIR}/location.svg" << 'EOL'
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path d="M12,2 C8.13,2 5,5.13 5,9 C5,14.25 12,22 12,22 C12,22 19,14.25 19,9 C19,5.13 15.87,2 12,2 Z" stroke="black" stroke-width="1.8" fill="none"/>
  <circle cx="12" cy="9" r="3" stroke="black" stroke-width="1.8" fill="none"/>
</svg>
EOL

# Refresh Icon
cat > "${TEMP_DIR}/refresh.svg" << 'EOL'
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path d="M17.65,6.35 C16.2,4.9 14.21,4 12,4 C7.58,4 4.01,7.58 4.01,12 C4.01,16.42 7.58,20 12,20 C15.73,20 18.84,17.45 19.73,14 L17.65,14 C16.83,16.33 14.61,18 12,18 C8.69,18 6,15.31 6,12 C6,8.69 8.69,6 12,6 C13.66,6 15.14,6.69 16.22,7.78 L13,11 L20,11 L20,4 L17.65,6.35 Z" fill="black"/>
</svg>
EOL

# Quit Icon
cat > "${TEMP_DIR}/quit.svg" << 'EOL'
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path d="M10.09,15.59 L11.5,17 L16.5,12 L11.5,7 L10.09,8.41 L12.67,11 L3,11 L3,13 L12.67,13 L10.09,15.59 Z" fill="black"/>
  <path d="M19,3 L5,3 C3.89,3 3,3.9 3,5 L3,9 L5,9 L5,5 L19,5 L19,19 L5,19 L5,15 L3,15 L3,19 C3,20.1 3.89,21 5,21 L19,21 C20.1,21 21,20.1 21,19 L21,5 C21,3.9 20.1,3 19,3 Z" fill="black"/>
</svg>
EOL
# Convert all SVGs to PNGs
echo "Converting all icons to PNG..."

# Convert menu bar icon
convert_svg_to_png "${TEMP_DIR}/menu-icon.svg" "${RESOURCES_DIR}/menu-icon.png" "22" "22"
convert_svg_to_png "${TEMP_DIR}/menu-icon.svg" "${RESOURCES_DIR}/menu-icon@2x.png" "44" "44"
echo "✅ Menu bar icon converted"

# Convert all menu item icons
MENU_ICONS=(
    "public-ip"
    "local-ip"
    "ssid"
    "dns"
    "vpn"
    "service"
    "isp"
    "location"
    "refresh"
    "quit"
)

for icon_name in "${MENU_ICONS[@]}"; do
    convert_svg_to_png "${TEMP_DIR}/${icon_name}.svg" "${RESOURCES_DIR}/${icon_name}.png" "24" "24"
    convert_svg_to_png "${TEMP_DIR}/${icon_name}.svg" "${RESOURCES_DIR}/${icon_name}@2x.png" "48" "48"
    echo "✅ Converted ${icon_name} icon"
done

# Clean up temporary files
rm -rf "${TEMP_DIR}"

echo "✨ All icons have been improved!"
echo "Rebuilding application..."

# Rebuild the application
swift build -c release

echo "✅ Build complete!"
echo "Copying app to NetworkInfo.app..."
cp -Rf .build/release/NetworkInfo NetworkInfo.app/Contents/MacOS/NetworkInfo

echo "✅ Done! NetworkInfo.app has been updated."
echo "You can now run the application with: open NetworkInfo.app"
