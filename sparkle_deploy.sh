#!/bin/bash

./build_release.sh

BUILT_PRODUCTS_DIR="$(pwd)/build/Release"
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
rm -f "$PROJECT_NAME"*.zip
ditto -ck --keepParent "$PROJECT_NAME.app" "$ARCHIVE_FILENAME"

SIZE=$(stat -f %z "$ARCHIVE_FILENAME")
PUBDATE=$(LC_TIME=en_US date +"%a, %d %b %G %T %z")
SIGNATURE=$("$WD"/sign_update.rb "$ARCHIVE_FILENAME" "$WD"/dsa_priv.pem)

[ $SIGNATURE ] || { echo Unable to load private key; false; }

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
    sparkle:dsaSignature="$SIGNATURE" />
</item>
EOF
