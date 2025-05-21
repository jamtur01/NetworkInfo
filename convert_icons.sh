#!/bin/bash

# Script to convert SVG icons to PNG and place them in the appropriate asset folders
# for the NetworkInfo app

set -e  # Exit immediately if a command exits with a non-zero status

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${BASE_DIR}/Sources/NetworkInfo"
RESOURCES_DIR="${SOURCE_DIR}/Resources"
TEMP_DIR="${BASE_DIR}/.tmp_icons"

# Create a temporary directory for SVG files
mkdir -p "${TEMP_DIR}"
mkdir -p "${RESOURCES_DIR}"

echo "=== NetworkInfo Icon Converter ==="
echo "This script will convert SVG icons to PNG format for your app."

# Check for required tools
if command -v inkscape >/dev/null 2>&1; then
    SVG_CONVERTER="inkscape"
    echo "✅ Using Inkscape for SVG conversion"
elif command -v convert >/dev/null 2>&1; then
    SVG_CONVERTER="imagemagick"
    echo "✅ Using ImageMagick for SVG conversion"
else
    echo "❌ Neither Inkscape nor ImageMagick (convert) found."
    echo "Please install one of these tools to continue:"
    echo "- Inkscape: brew install inkscape"
    echo "- ImageMagick: brew install imagemagick"
    exit 1
fi

# Function to convert SVG to PNG using the available converter
convert_svg_to_png() {
    local svg_file=$1
    local output_file=$2
    local width=$3
    local height=$4
    
    echo "Converting: ${svg_file} to ${output_file} (${width}x${height})"
    
    if [ "${SVG_CONVERTER}" = "inkscape" ]; then
        inkscape --export-filename="${output_file}" \
                 --export-width="${width}" \
                 --export-height="${height}" \
                 "${svg_file}" >/dev/null 2>&1
    else
        convert -background none -resize "${width}x${height}" "${svg_file}" "${output_file}"
    fi
}

# Extract SVGs from function results and save to temp files
echo "Creating temporary SVG files..."

# Extract the app icon SVG from the artifact
cat > "${TEMP_DIR}/app-icon.svg" << 'EOL'
<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">
  <!-- Background Circle -->
  <circle cx="256" cy="256" r="256" fill="#0046B8"/>
  
  <!-- Gradient Layer -->
  <circle cx="256" cy="256" r="240" fill="url(#gradient)"/>
  
  <!-- Network Node Points -->
  <circle cx="128" cy="128" r="30" fill="#FFFFFF"/>
  <circle cx="384" cy="128" r="30" fill="#FFFFFF"/>
  <circle cx="128" cy="384" r="30" fill="#FFFFFF"/>
  <circle cx="384" cy="384" r="30" fill="#FFFFFF"/>
  <circle cx="256" cy="256" r="40" fill="#FFFFFF"/>
  
  <!-- Connection Lines -->
  <line x1="128" y1="128" x2="256" y2="256" stroke="#FFFFFF" stroke-width="12"/>
  <line x1="384" y1="128" x2="256" y2="256" stroke="#FFFFFF" stroke-width="12"/>
  <line x1="128" y1="384" x2="256" y2="256" stroke="#FFFFFF" stroke-width="12"/>
  <line x1="384" y1="384" x2="256" y2="256" stroke="#FFFFFF" stroke-width="12"/>
  
  <!-- Data Packet Animation -->
  <circle cx="192" cy="192" r="12" fill="#4CFFB5"/>
  <circle cx="320" cy="192" r="12" fill="#4CFFB5"/>
  <circle cx="192" cy="320" r="12" fill="#4CFFB5"/>
  <circle cx="320" cy="320" r="12" fill="#4CFFB5"/>
  
  <!-- Gradient Definition -->
  <defs>
    <linearGradient id="gradient" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#0059E3;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#003693;stop-opacity:1" />
    </linearGradient>
  </defs>
</svg>
EOL

# Extract the menu icon SVG
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

# Extract other menu icons
cat > "${TEMP_DIR}/public-ip.svg" << 'EOL'
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <circle cx="12" cy="12" r="10" fill="none" stroke="black" stroke-width="1.8"/>
  <path d="M12,2 C6.48,2 2,6.48 2,12 C2,17.52 6.48,22 12,22 C17.52,22 22,17.52 22,12 C22,6.48 17.52,2 12,2 Z M3.7,12 C3.7,12 6,15 12,15 C18,15 20.3,12 20.3,12 C20.3,12 18,9 12,9 C6,9 3.7,12 3.7,12 Z" fill="black" fill-rule="evenodd" opacity="0.5"/>
  <circle cx="12" cy="12" r="3" fill="black"/>
</svg>
EOL

cat > "${TEMP_DIR}/local-ip.svg" << 'EOL'
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <rect x="4" y="4" width="16" height="12" rx="2" fill="none" stroke="currentColor" stroke-width="2"/>
  <path d="M8,20 L16,20" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
  <path d="M12,16 L12,20" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
  <circle cx="8" cy="9" r="1.5" fill="currentColor"/>
  <circle cx="12" cy="9" r="1.5" fill="currentColor"/>
  <circle cx="16" cy="9" r="1.5" fill="currentColor"/>
</svg>
EOL

cat > "${TEMP_DIR}/ssid.svg" << 'EOL'
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path d="M4,12 C6.33,9.67 9.67,9 12,9 C14.33,9 17.67,9.67 20,12" stroke="currentColor" stroke-width="2" stroke-linecap="round" fill="none"/>
  <path d="M7,15 C8.33,13.67 10.33,13 12,13 C13.67,13 15.67,13.67 17,15" stroke="currentColor" stroke-width="2" stroke-linecap="round" fill="none"/>
  <circle cx="12" cy="18" r="2" fill="currentColor"/>
</svg>
EOL

cat > "${TEMP_DIR}/dns.svg" << 'EOL'
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <rect x="3" y="5" width="18" height="14" rx="2" stroke="currentColor" stroke-width="2" fill="none"/>
  <path d="M7,9 L17,9" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
  <path d="M7,13 L14,13" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
  <path d="M7,17 L12,17" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
</svg>
EOL

cat > "${TEMP_DIR}/vpn.svg" << 'EOL'
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="2" fill="none"/>
  <path d="M12,3 C7.03,3 3,7.03 3,12 L21,12 C21,7.03 16.97,3 12,3 Z" fill="currentColor" opacity="0.5"/>
  <rect x="9" y="10" width="6" height="8" rx="1" stroke="currentColor" stroke-width="2" fill="none"/>
  <circle cx="12" cy="13" r="1" fill="currentColor"/>
  <path d="M12,13 L12,16" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
</svg>
EOL

cat > "${TEMP_DIR}/service.svg" << 'EOL'
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path d="M12,4 L12,8" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
  <path d="M16,6 L14,9.5" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
  <path d="M8,6 L10,9.5" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
  <path d="M4,12 L8,12" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
  <path d="M16,12 L20,12" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
  <path d="M6,17 L9.5,15" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
  <path d="M14.5,15 L18,17" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
  <circle cx="12" cy="12" r="3" fill="currentColor"/>
</svg>
EOL

cat > "${TEMP_DIR}/isp.svg" << 'EOL'
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path d="M4,6 L20,6 L20,18 L4,18 L4,6 Z" stroke="currentColor" stroke-width="2" fill="none"/>
  <path d="M8,6 L8,18" stroke="currentColor" stroke-width="2"/>
  <path d="M16,6 L16,18" stroke="currentColor" stroke-width="2"/>
  <path d="M4,12 L20,12" stroke="currentColor" stroke-width="2"/>
</svg>
EOL

cat > "${TEMP_DIR}/location.svg" << 'EOL'
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path d="M12,2 C8.13,2 5,5.13 5,9 C5,14.25 12,22 12,22 C12,22 19,14.25 19,9 C19,5.13 15.87,2 12,2 Z" stroke="currentColor" stroke-width="2" fill="none"/>
  <circle cx="12" cy="9" r="3" stroke="currentColor" stroke-width="2" fill="none"/>
</svg>
EOL

cat > "${TEMP_DIR}/refresh.svg" << 'EOL'
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path d="M17.65,6.35 C16.2,4.9 14.21,4 12,4 C7.58,4 4.01,7.58 4.01,12 C4.01,16.42 7.58,20 12,20 C15.73,20 18.84,17.45 19.73,14 L17.65,14 C16.83,16.33 14.61,18 12,18 C8.69,18 6,15.31 6,12 C6,8.69 8.69,6 12,6 C13.66,6 15.14,6.69 16.22,7.78 L13,11 L20,11 L20,4 L17.65,6.35 Z" fill="currentColor"/>
</svg>
EOL

cat > "${TEMP_DIR}/quit.svg" << 'EOL'
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path d="M10.09,15.59 L11.5,17 L16.5,12 L11.5,7 L10.09,8.41 L12.67,11 L3,11 L3,13 L12.67,13 L10.09,15.59 Z" fill="currentColor"/>
  <path d="M19,3 L5,3 C3.89,3 3,3.9 3,5 L3,9 L5,9 L5,5 L19,5 L19,19 L5,19 L5,15 L3,15 L3,19 C3,20.1 3.89,21 5,21 L19,21 C20.1,21 21,20.1 21,19 L21,5 C21,3.9 20.1,3 19,3 Z" fill="currentColor"/>
</svg>
EOL

# Function to replace "currentColor" with a specific color in SVG files
replace_current_color() {
    local svg_file=$1
    local color=$2
    local output_file=$3
    
    sed "s/currentColor/${color}/g" "${svg_file}" > "${output_file}"
}

# Create app icons
echo "Converting app icon to PNG..."
APP_ICON_SIZES=(16 32 64 128 256 512 1024)
APP_ICON_DIR="${RESOURCES_DIR}/AppIcon.iconset"
mkdir -p "${APP_ICON_DIR}"

for size in "${APP_ICON_SIZES[@]}"; do
    convert_svg_to_png "${TEMP_DIR}/app-icon.svg" "${APP_ICON_DIR}/icon_${size}x${size}.png" "${size}" "${size}"
    
    # For 2x versions
    if [ $size -le 512 ]; then
        convert_svg_to_png "${TEMP_DIR}/app-icon.svg" "${APP_ICON_DIR}/icon_${size}x${size}@2x.png" "$((size*2))" "$((size*2))"
    fi
done

# Create .icns file from the iconset
if command -v iconutil >/dev/null 2>&1; then
    echo "Creating .icns file from iconset..."
    iconutil -c icns "${APP_ICON_DIR}" -o "${RESOURCES_DIR}/AppIcon.icns"
    echo "✅ Created AppIcon.icns"
else
    echo "⚠️ iconutil command not found, skipping .icns creation"
fi

# Process menu bar icon (template icon)
echo "Converting menu bar icon..."
replace_current_color "${TEMP_DIR}/menu-icon.svg" "black" "${TEMP_DIR}/menu-icon-black.svg"
convert_svg_to_png "${TEMP_DIR}/menu-icon-black.svg" "${RESOURCES_DIR}/menu-icon.png" "22" "22"
convert_svg_to_png "${TEMP_DIR}/menu-icon-black.svg" "${RESOURCES_DIR}/menu-icon@2x.png" "44" "44"
echo "✅ Menu bar icon conversion complete"

# Process menu item icons
echo "Converting menu item icons..."
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
    # Process as template icons (black)
    replace_current_color "${TEMP_DIR}/${icon_name}.svg" "black" "${TEMP_DIR}/${icon_name}-black.svg"
    convert_svg_to_png "${TEMP_DIR}/${icon_name}-black.svg" "${RESOURCES_DIR}/${icon_name}.png" "24" "24"
    convert_svg_to_png "${TEMP_DIR}/${icon_name}-black.svg" "${RESOURCES_DIR}/${icon_name}@2x.png" "48" "48"
    
    echo "✅ Converted ${icon_name} icon"
done

echo "Cleaning up temporary files..."
rm -rf "${TEMP_DIR}"

echo "✨ All icons have been successfully converted and placed in their directories!"
echo "🔨 Build your app to see the changes."

