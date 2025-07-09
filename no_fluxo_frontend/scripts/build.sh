#!/bin/bash

echo "🚀 Starting Flutter web build for Vercel..."

# Install Flutter if not available
if ! command -v flutter &> /dev/null; then
    echo "📦 Flutter not found, installing..."
    
    # Install Flutter
    curl -L https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.5-stable.tar.xz -o flutter.tar.xz
    tar xf flutter.tar.xz
    export PATH="$PATH:`pwd`/flutter/bin"
    
    # Precache web
    flutter precache --web
else
    echo "✅ Flutter found"
fi

# Check Flutter version
flutter --version

# Enable web
flutter config --enable-web

# Get dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Prepare build arguments
BUILD_ARGS=""

# Check for NO_FLUXO_PROD environment variable
if [ ! -z "$NO_FLUXO_PROD" ]; then
    echo "🏭 Production environment detected (NO_FLUXO_PROD=$NO_FLUXO_PROD)"
    BUILD_ARGS="--dart-define=NO_FLUXO_PROD=true"
else
    echo "🧪 Development environment (NO_FLUXO_PROD not set)"
    BUILD_ARGS="--dart-define=NO_FLUXO_PROD=false"
fi

# Build for web
echo "🔨 Building Flutter web with args: $BUILD_ARGS"
flutter build web --release --web-renderer html $BUILD_ARGS

echo "✅ Build completed successfully!"
echo "📁 Build output is in build/web/"

# List build directory contents for debugging
ls -la build/web/ 