#!/bin/bash

# A script that runs the icon conversion and rebuilds the app

set -e  # Exit immediately if a command exits with a non-zero status

echo "=== NetworkInfo Build Script ==="
echo "Converting icons and rebuilding app..."

# Run the icon conversion script
./convert_icons.sh

# Rebuild the application
echo "Building NetworkInfo app..."
swift build -c release

echo "✨ Build complete!"
echo "The app is available at: .build/release/NetworkInfo"

# Optional: Copy the app to the application folder
echo "Copying app to NetworkInfo.app..."
cp -Rf .build/release/NetworkInfo NetworkInfo.app/Contents/MacOS/NetworkInfo

echo "✅ Done! NetworkInfo.app has been updated."
echo "You can now run the application."
