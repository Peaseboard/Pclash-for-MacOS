#!/bin/bash
# PClash Build Script
# Usage: ./build.sh [android|macos|windows|linux|all]

set -e

echo "🐌 PClash Build Script"
echo "===================="

# Check Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter first."
    exit 1
fi

echo "✅ Flutter: $(flutter --version | head -n 1)"

# Get dependencies
echo ""
echo "📦 Getting dependencies..."
flutter pub get

# Check mihomo binaries
echo ""
echo "🔍 Checking mihomo binaries..."
MIHOMO_DIR="assets/mihomo"
MISSING_BINARIES=0

for binary in mihomo-darwin-arm64 mihomo-darwin-amd64 mihomo-android-arm64 mihomo-android-amd64; do
    if [ ! -f "$MIHOMO_DIR/$binary" ]; then
        echo "  ⚠️  Missing: $binary"
        MISSING_BINARIES=$((MISSING_BINARIES + 1))
    else
        echo "  ✅ Found: $binary ($(du -h "$MIHOMO_DIR/$binary" | cut -f1))"
    fi
done

if [ $MISSING_BINARIES -gt 0 ]; then
    echo ""
    echo "⚠️  Warning: $MISSING_BINARIES mihomo binary(ies) missing."
    echo "   Download from: https://github.com/MetaCubeX/mihomo/releases"
    echo "   Place in: $MIHOMO_DIR/"
    echo ""
fi

# Build function
build_platform() {
    local platform=$1
    
    echo ""
    echo "🔨 Building for $platform..."
    
    case $platform in
        android)
            flutter build apk --release
            echo ""
            echo "✅ APK: build/app/outputs/flutter-apk/app-release.apk"
            echo "✅ App Bundle: flutter build appbundle --release (for Google Play)"
            ;;
        macos)
            flutter build macos --release
            echo ""
            echo "✅ macOS: build/macos/Build/Products/Release/pclash.app"
            ;;
        windows)
            local arch=${2:-x64}
            flutter build windows --release --target-platform=windows-$arch
            echo ""
            echo "✅ Windows ($arch): build/windows/$arch/runner/Release/pclash.exe"
            ;;
        linux)
            flutter build linux --release
            echo ""
            echo "✅ Linux: build/linux/x64/release/bundle/pclash"
            ;;
        *)
            echo "❌ Unknown platform: $platform"
            echo "   Supported: android, macos, windows, linux"
            exit 1
            ;;
    esac
}

# Main
PLATFORM=${1:-all}

if [ "$PLATFORM" = "all" ]; then
    build_platform "macos"
    build_platform "android"
    build_platform "windows"
    build_platform "linux"
else
    build_platform "$PLATFORM"
fi

echo ""
echo "✨ Build complete!"
