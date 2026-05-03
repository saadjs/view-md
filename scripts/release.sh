#!/usr/bin/env bash
# Build, sign, notarize, and package a Developer ID release of ViewMD as a DMG.
#
# Usage:   scripts/release.sh <version>
# Example: scripts/release.sh 0.1.0
#
# Requires: a "Developer ID Application" certificate in the keychain and a
# stored notarytool keychain profile named $NOTARY_PROFILE.

set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "usage: $0 <version>" >&2
  exit 1
fi

SCHEME="ViewMD"
APP_NAME="ViewMD"
TEAM_ID="2ZPA772V9V"
NOTARY_PROFILE="view-md-notary"
DEVELOPER_ID_APPLICATION="${DEVELOPER_ID_APPLICATION:-Developer ID Application: Saad Bash ($TEAM_ID)}"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$REPO_ROOT/build/release"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
APP_PATH="$EXPORT_DIR/$APP_NAME.app"
APP_ZIP="$BUILD_DIR/$APP_NAME.zip"
DMG_STAGE="$BUILD_DIR/dmg-stage"
DMG_PATH="$BUILD_DIR/${APP_NAME}-${VERSION}.dmg"
EXPORT_OPTIONS="$BUILD_DIR/ExportOptions.plist"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

verify_app_signature() {
  local app_path="$1"

  codesign --verify --strict --verbose=4 "$app_path"
}

verify_notarized_app() {
  local app_path="$1"

  verify_app_signature "$app_path"
  xcrun stapler validate "$app_path"
  spctl -a -vvv -t exec "$app_path"
}

verify_notarized_dmg() {
  local dmg_path="$1"

  codesign --verify --strict --verbose=4 "$dmg_path"
  xcrun stapler validate "$dmg_path"
  spctl -a -vvv -t open --context context:primary-signature "$dmg_path"
  hdiutil verify "$dmg_path"
}

cat > "$EXPORT_OPTIONS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
</dict>
</plist>
EOF

echo "==> Archiving $SCHEME ($VERSION)"
xcodebuild archive \
  -project "$REPO_ROOT/ViewMD.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  MARKETING_VERSION="$VERSION"

echo "==> Exporting Developer ID-signed app"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS"

echo "==> Verifying exported app signature"
verify_app_signature "$APP_PATH"

echo "==> Notarizing app"
ditto -c -k --keepParent "$APP_PATH" "$APP_ZIP"
xcrun notarytool submit "$APP_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling app"
xcrun stapler staple "$APP_PATH"

echo "==> Verifying notarized app"
verify_notarized_app "$APP_PATH"

echo "==> Building DMG"
mkdir -p "$DMG_STAGE"
cp -R "$APP_PATH" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"
hdiutil create \
  -volname "$APP_NAME $VERSION" \
  -srcfolder "$DMG_STAGE" \
  -ov -format UDZO \
  "$DMG_PATH"

echo "==> Signing DMG"
codesign --force --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$DMG_PATH"
codesign --verify --strict --verbose=4 "$DMG_PATH"

echo "==> Notarizing DMG"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling DMG"
xcrun stapler staple "$DMG_PATH"

echo "==> Verifying notarized DMG"
verify_notarized_dmg "$DMG_PATH"

SHA256="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"

echo
echo "================================================================"
echo " Release artifact ready"
echo "----------------------------------------------------------------"
echo " Path:    $DMG_PATH"
echo " Version: $VERSION"
echo " SHA256:  $SHA256"
echo "================================================================"
