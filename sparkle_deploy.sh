#!/bin/bash

set -eo pipefail

BUILD_DIR="$(pwd)/build"

echo "----> cleaning..."
rm -rvf "$BUILD_DIR"

echo "----> building..."
xcodebuild -workspace gfxCardStatus.xcworkspace -scheme gfxCardStatus -configuration Release SYMROOT="$BUILD_DIR" OBJROOT="$BUILD_DIR/obj"

BUILT_PRODUCTS_DIR="$BUILD_DIR/Release"
PROJECT_NAME="gfxCardStatus"
VERSION="$(defaults read "$BUILT_PRODUCTS_DIR/$PROJECT_NAME.app/Contents/Info.plist" CFBundleShortVersionString)"
BUILD_VERSION="$(defaults read "$BUILT_PRODUCTS_DIR/$PROJECT_NAME.app/Contents/Info.plist" CFBundleVersion)"
DEPLOYMENT_TARGET="$(defaults read "$BUILT_PRODUCTS_DIR/$PROJECT_NAME.app/Contents/Info.plist" LSMinimumSystemVersion)"
DOWNLOAD_BASE_URL="https://gfx.io/downloads"
RELEASENOTES_URL="https://gfx.io/releasenotes/$VERSION.html"

ARCHIVE_FILENAME="$PROJECT_NAME-$VERSION.zip"
DOWNLOAD_URL="$DOWNLOAD_BASE_URL/$ARCHIVE_FILENAME"
KEYCHAIN_PRIVKEY_NAME="Sparkle Private Key"

WD=$PWD
cd "$BUILT_PRODUCTS_DIR"

echo "----> archiving app..."
ditto -ck --keepParent "$PROJECT_NAME.app" "$ARCHIVE_FILENAME"

SIZE=$(stat -f %z "$ARCHIVE_FILENAME")
PUBDATE=$(LC_TIME=en_US date +"%a, %d %b %G %T %z")

echo "----> signing archive (dsa)..."
DSA_SIGNATURE="$("$WD"/sign_update_dsa.rb "$ARCHIVE_FILENAME" "$WD"/dsa_priv.pem)"
[ $DSA_SIGNATURE ] || { echo "DSA signing failed (unable to load private key?)"; false; }

echo "----> signing archive (ed25519)..."
ED25519_SIGNATURE="$($WD/sign_update "$ARCHIVE_FILENAME" | sed -E 's/^sparkle:edSignature="(.+)" length=".*"$/\1/g')"
[ $ED25519_SIGNATURE ] || { echo "Ed25519 signing failed"; false; }

echo -e "----> done! drop this into the relevant appcast(s):\n"

cat <<EOF
<item>
  <title>Version $VERSION</title>
  <sparkle:releaseNotesLink>
    $RELEASENOTES_URL
  </sparkle:releaseNotesLink>
  <pubDate>$PUBDATE</pubDate>
  <sparkle:minimumSystemVersion>$DEPLOYMENT_TARGET</sparkle:minimumSystemVersion>
  <enclosure url="$DOWNLOAD_URL"
    sparkle:version="$BUILD_VERSION"
    sparkle:shortVersionString="$VERSION"
    type="application/octet-stream"
    length="$SIZE"
    sparkle:dsaSignature="$DSA_SIGNATURE"
    sparkle:edSignature="$ED25519_SIGNATURE" />
</item>
EOF
