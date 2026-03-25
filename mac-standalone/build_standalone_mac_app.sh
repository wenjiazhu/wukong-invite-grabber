#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"
source "$PROJECT_ROOT/mac-assets/app_metadata.sh"

APP_BUNDLE="$DIST_DIR/$APP_NAME"
ICON_FILE="$PROJECT_ROOT/mac-assets/build/AppIcon.icns"

SWIFT_SOURCE="$SCRIPT_DIR/WukongInviteGrabberStandalone.swift"
HTML_FILE="$PROJECT_ROOT/wukong-invite-grabber.html"
USAGE_FILE="$PROJECT_ROOT/wukong-invite-grabber-usage.md"

for file in "$SWIFT_SOURCE" "$HTML_FILE" "$USAGE_FILE" "$PROJECT_ROOT/mac-assets/generate_icons.sh"; do
  if [[ ! -f "$file" ]]; then
    echo "Missing required file: $file" >&2
    exit 1
  fi
done

bash "$PROJECT_ROOT/mac-assets/generate_icons.sh" >/dev/null

if [[ ! -f "$ICON_FILE" ]]; then
  echo "Missing generated icon: $ICON_FILE" >&2
  exit 1
fi

rm -rf "$APP_BUNDLE"
mkdir -p \
  "$APP_BUNDLE/Contents/MacOS" \
  "$APP_BUNDLE/Contents/Resources/app/prototype"

/usr/bin/swiftc \
  -O \
  -parse-as-library \
  -framework AppKit \
  -framework WebKit \
  -framework Vision \
  -framework ImageIO \
  "$SWIFT_SOURCE" \
  -o "$APP_BUNDLE/Contents/MacOS/$APP_EXECUTABLE_NAME"

cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_DISPLAY_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_EXECUTABLE_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>$APP_BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_DISPLAY_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_BUILD</string>
  <key>LSApplicationCategoryType</key>
  <string>$APP_CATEGORY</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>$APPLE_EVENTS_USAGE</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>$COPYRIGHT_NOTICE</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
EOF

cp "$HTML_FILE" "$APP_BUNDLE/Contents/Resources/app/prototype/"
cp "$USAGE_FILE" "$APP_BUNDLE/Contents/Resources/app/prototype/"
cp "$ICON_FILE" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

echo "Built standalone app bundle:"
echo "  $APP_BUNDLE"
