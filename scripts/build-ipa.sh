#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PRODUCT_NAME="ShareToMail"
OUTPUT_DIR="$PROJECT_DIR/build"
IPA_PATH="$OUTPUT_DIR/$PRODUCT_NAME.ipa"

# Clean previous build
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/Payload"

# Build for device
echo "Building $PRODUCT_NAME for device..."
xcodebuild \
    -project "$PROJECT_DIR/$PRODUCT_NAME.xcodeproj" \
    -scheme "$PRODUCT_NAME" \
    -destination 'generic/platform=iOS' \
    -configuration Debug \
    -derivedDataPath "$OUTPUT_DIR/DerivedData" \
    CODE_SIGNING_ALLOWED=NO \
    build

# Find the .app
APP_PATH=$(find "$OUTPUT_DIR/DerivedData/Build/Products/Debug-iphoneos" -name "$PRODUCT_NAME.app" -maxdepth 1)
if [ -z "$APP_PATH" ]; then
    echo "Error: $PRODUCT_NAME.app not found"
    exit 1
fi

# Package as .ipa
echo "Packaging .ipa..."
cp -r "$APP_PATH" "$OUTPUT_DIR/Payload/"
cd "$OUTPUT_DIR"
zip -r "$IPA_PATH" Payload
rm -rf Payload DerivedData

echo "Done: $IPA_PATH"
