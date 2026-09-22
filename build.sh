#!/bin/bash
set -e

echo "==============================================="
echo "  Flutter Web Build Script for Vercel Deploy   "
echo "==============================================="

# Step 1: Install / Locate Flutter SDK
if command -v flutter &> /dev/null; then
  echo ">>> Flutter is already available in PATH."
else
  echo ">>> Flutter not found in PATH. Checking local directory..."
  if [ ! -d "flutter" ]; then
    echo ">>> Cloning Flutter SDK (stable branch)..."
    git clone https://github.com/flutter/flutter.git --depth 1 -b stable flutter
  fi
  export PATH="$PATH:$(pwd)/flutter/bin"
fi

# Step 2: Show version info
echo ">>> Flutter Version:"
flutter --version

# Step 3: Enable web support
echo ">>> Enabling Flutter Web..."
flutter config --enable-web

# Step 4: Resolve package dependencies
echo ">>> Running flutter pub get..."
flutter pub get

# Step 5: Build Flutter Web release bundle
echo ">>> Building Flutter Web in release mode..."
flutter build web --release --base-href /

# Step 6: Verify build output
if [ -f "build/web/index.html" ]; then
  echo "==============================================="
  echo ">>> Build completed successfully!"
  echo ">>> Output ready at: build/web"
  echo "==============================================="
else
  echo ">>> ERROR: build/web/index.html not found!"
  exit 1
fi
