#!/bin/bash

# The Book - Build and Release Script
# This script automates building and signing the Android app for release

set -e

echo "====================================="
echo "The Book - Android Build & Release"
echo "====================================="
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if gradle exists
if ! command -v ./gradlew &> /dev/null; then
    echo -e "${RED}Error: gradlew not found. Please run from project root.${NC}"
    exit 1
fi

# Menu
echo "Choose build type:"
echo "1) Debug APK"
echo "2) Release APK (signed)"
echo "3) Release Bundle (AAB - for Play Store)"
echo "4) Clean and build Release Bundle"
echo ""
read -p "Enter choice [1-4]: " choice

case $choice in
    1)
        echo -e "${YELLOW}Building Debug APK...${NC}"
        ./gradlew assembleDebug
        APK_PATH="app/build/outputs/apk/debug/app-debug.apk"
        echo -e "${GREEN}✓ Debug APK created: $APK_PATH${NC}"
        ;;
    2)
        echo -e "${YELLOW}Building Release APK...${NC}"
        echo "Note: You'll be prompted for keystore details"
        ./gradlew assembleRelease
        APK_PATH="app/build/outputs/apk/release/app-release.apk"
        echo -e "${GREEN}✓ Release APK created: $APK_PATH${NC}"
        ;;
    3)
        echo -e "${YELLOW}Building Release Bundle (AAB)...${NC}"
        echo "Note: You'll be prompted for keystore details"
        ./gradlew bundleRelease
        BUNDLE_PATH="app/build/outputs/bundle/release/app-release.aab"
        echo -e "${GREEN}✓ Release Bundle created: $BUNDLE_PATH${NC}"
        ;;
    4)
        echo -e "${YELLOW}Cleaning project...${NC}"
        ./gradlew clean
        echo -e "${YELLOW}Building Release Bundle...${NC}"
        ./gradlew bundleRelease
        BUNDLE_PATH="app/build/outputs/bundle/release/app-release.aab"
        echo -e "${GREEN}✓ Release Bundle created: $BUNDLE_PATH${NC}"
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}Build completed successfully!${NC}"
echo ""
echo "Next steps:"
echo "1. Test the build on a device/emulator"
echo "2. Check LAUNCH_CHECKLIST.md before submitting"
echo "3. Upload to Google Play Console"
