#!/bin/bash

# Script de release automatique pour SurrenderOverlay avec signature Sparkle
# Usage: ./release.sh 1.0.4

set -e  # Exit on error

if [ -z "$1" ]; then
    echo "❌ Usage: ./release.sh <version>"
    echo "   Example: ./release.sh 1.0.4"
    exit 1
fi

VERSION="$1"
APP_NAME="SurrenderOverlay"
BUILD_DIR="build/Build/Products/Release"
ZIP_NAME="${APP_NAME}-${VERSION}.zip"
SIGN_TOOL="build/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update"

echo "🚀 Building ${APP_NAME} v${VERSION}..."

# 1. Clean and build
rm -rf build/
xcodebuild -project ${APP_NAME}.xcodeproj \
  -scheme ${APP_NAME} \
  -configuration Release \
  -derivedDataPath build \
  clean build

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

echo "✅ Build successful!"

# 2. Create ZIP
cd ${BUILD_DIR}
echo "📦 Creating ZIP..."
ditto -c -k --sequesterRsrc --keepParent \
  ${APP_NAME}.app \
  ${ZIP_NAME}

# 3. Sign the ZIP
cd ../../../../
echo "🔐 Signing ZIP with Sparkle EdDSA..."

if [ ! -f "${SIGN_TOOL}" ]; then
    echo "❌ Sign tool not found at ${SIGN_TOOL}"
    echo "   Make sure you've built the project at least once to download Sparkle"
    exit 1
fi

SIGNATURE_OUTPUT=$(${SIGN_TOOL} ${BUILD_DIR}/${ZIP_NAME})
echo "✅ Signature generated:"
echo "   ${SIGNATURE_OUTPUT}"

# Extract signature and length
ED_SIGNATURE=$(echo "$SIGNATURE_OUTPUT" | grep -o 'sparkle:edSignature="[^"]*"' | cut -d'"' -f2)
FILE_LENGTH=$(echo "$SIGNATURE_OUTPUT" | grep -o 'length="[^"]*"' | cut -d'"' -f2)

# 4. Get version info from Info.plist
BUNDLE_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" ${APP_NAME}/Info.plist)
SHORT_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" ${APP_NAME}/Info.plist)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Release ready for v${VERSION}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📦 ZIP Location:"
echo "   ${BUILD_DIR}/${ZIP_NAME}"
echo ""
echo "📋 Next steps:"
echo ""
echo "1. Upload to GitHub Releases:"
echo "   gh release create v${VERSION} ${BUILD_DIR}/${ZIP_NAME} \\"
echo "     --title \"v${VERSION}\" \\"
echo "     --notes \"Release notes here\""
echo ""
echo "2. Add this to appcast.xml (before existing items):"
echo ""
echo "    <item>"
echo "        <title>Version ${VERSION}</title>"
echo "        <sparkle:releaseNotesLink>"
echo "            https://github.com/JeanBoudin/surrenderOverlay/releases/tag/v${VERSION}"
echo "        </sparkle:releaseNotesLink>"
echo "        <pubDate>$(date -u '+%a, %d %b %Y %H:%M:%S +0000')</pubDate>"
echo "        <enclosure"
echo "            url=\"https://github.com/JeanBoudin/surrenderOverlay/releases/download/v${VERSION}/${ZIP_NAME}\""
echo "            sparkle:version=\"${BUNDLE_VERSION}\""
echo "            sparkle:shortVersionString=\"${SHORT_VERSION}\""
echo "            sparkle:edSignature=\"${ED_SIGNATURE}\""
echo "            length=\"${FILE_LENGTH}\""
echo "            type=\"application/octet-stream\""
echo "        />"
echo "    </item>"
echo ""
echo "3. Commit and push appcast.xml:"
echo "   git add appcast.xml"
echo "   git commit -m \"Release v${VERSION}\""
echo "   git push"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
