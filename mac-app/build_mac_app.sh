#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"
source "$PROJECT_ROOT/mac-assets/app_metadata.sh"

APP_BUNDLE="$DIST_DIR/$APP_NAME"
STOP_APP_BUNDLE="$DIST_DIR/$STOP_APP_NAME"
MAIN_ICON_FILE="$PROJECT_ROOT/mac-assets/build/AppIcon.icns"
STOP_ICON_FILE="$PROJECT_ROOT/mac-assets/build/StopAppIcon.icns"

HTML_FILE="$PROJECT_ROOT/wukong-invite-grabber.html"
USAGE_FILE="$PROJECT_ROOT/wukong-invite-grabber-usage.md"
BRIDGE_FILE="$PROJECT_ROOT/tools/wukong_macos_ocr_bridge.py"
VISION_FILE="$PROJECT_ROOT/tools/vision_ocr.m"
PREPROCESS_FILE="$PROJECT_ROOT/tools/preprocess_invite_image.m"
PLIST_TOOL="/usr/bin/plutil"

for file in \
  "$HTML_FILE" \
  "$USAGE_FILE" \
  "$BRIDGE_FILE" \
  "$VISION_FILE" \
  "$PREPROCESS_FILE" \
  "$PROJECT_ROOT/mac-assets/generate_icons.sh" \
  "$SCRIPT_DIR/start_wukong_invite_grabber.sh" \
  "$SCRIPT_DIR/stop_wukong_invite_grabber.sh" \
  "$SCRIPT_DIR/Wukong Invite Grabber.applescript" \
  "$SCRIPT_DIR/Stop Wukong Invite Grabber.applescript"; do
  if [[ ! -f "$file" ]]; then
    echo "Missing required file: $file" >&2
    exit 1
  fi
done

bash "$PROJECT_ROOT/mac-assets/generate_icons.sh" >/dev/null

for icon_file in "$MAIN_ICON_FILE" "$STOP_ICON_FILE"; do
  if [[ ! -f "$icon_file" ]]; then
    echo "Missing generated icon: $icon_file" >&2
    exit 1
  fi
done

mkdir -p "$DIST_DIR"
rm -rf "$APP_BUNDLE" "$STOP_APP_BUNDLE"

/usr/bin/osacompile -o "$APP_BUNDLE" "$SCRIPT_DIR/Wukong Invite Grabber.applescript"
/usr/bin/osacompile -o "$STOP_APP_BUNDLE" "$SCRIPT_DIR/Stop Wukong Invite Grabber.applescript"

mkdir -p "$APP_BUNDLE/Contents/Resources/app/prototype/tools"
cp "$HTML_FILE" "$APP_BUNDLE/Contents/Resources/app/prototype/"
cp "$USAGE_FILE" "$APP_BUNDLE/Contents/Resources/app/prototype/"
cp "$BRIDGE_FILE" "$APP_BUNDLE/Contents/Resources/app/prototype/tools/"
cp "$VISION_FILE" "$APP_BUNDLE/Contents/Resources/app/prototype/tools/"
cp "$PREPROCESS_FILE" "$APP_BUNDLE/Contents/Resources/app/prototype/tools/"
cp "$SCRIPT_DIR/start_wukong_invite_grabber.sh" "$APP_BUNDLE/Contents/Resources/"
cp "$SCRIPT_DIR/stop_wukong_invite_grabber.sh" "$APP_BUNDLE/Contents/Resources/"
cp "$MAIN_ICON_FILE" "$APP_BUNDLE/Contents/Resources/applet.icns"

chmod +x \
  "$APP_BUNDLE/Contents/Resources/start_wukong_invite_grabber.sh" \
  "$APP_BUNDLE/Contents/Resources/stop_wukong_invite_grabber.sh"

cp "$SCRIPT_DIR/stop_wukong_invite_grabber.sh" "$STOP_APP_BUNDLE/Contents/Resources/"
chmod +x "$STOP_APP_BUNDLE/Contents/Resources/stop_wukong_invite_grabber.sh"
cp "$STOP_ICON_FILE" "$STOP_APP_BUNDLE/Contents/Resources/applet.icns"

update_launcher_plist() {
  local plist_path="$1"
  local bundle_name="$2"
  local bundle_identifier="$3"

  "$PLIST_TOOL" -replace CFBundleDisplayName -string "$bundle_name" "$plist_path" 2>/dev/null || \
    "$PLIST_TOOL" -insert CFBundleDisplayName -string "$bundle_name" "$plist_path"
  "$PLIST_TOOL" -replace CFBundleIdentifier -string "$bundle_identifier" "$plist_path" 2>/dev/null || \
    "$PLIST_TOOL" -insert CFBundleIdentifier -string "$bundle_identifier" "$plist_path"
  "$PLIST_TOOL" -replace CFBundleShortVersionString -string "$APP_VERSION" "$plist_path" 2>/dev/null || \
    "$PLIST_TOOL" -insert CFBundleShortVersionString -string "$APP_VERSION" "$plist_path"
  "$PLIST_TOOL" -replace CFBundleVersion -string "$APP_BUILD" "$plist_path" 2>/dev/null || \
    "$PLIST_TOOL" -insert CFBundleVersion -string "$APP_BUILD" "$plist_path"
  "$PLIST_TOOL" -replace LSMinimumSystemVersion -string "$MIN_SYSTEM_VERSION" "$plist_path" 2>/dev/null || \
    "$PLIST_TOOL" -insert LSMinimumSystemVersion -string "$MIN_SYSTEM_VERSION" "$plist_path"
  "$PLIST_TOOL" -replace LSApplicationCategoryType -string "$APP_CATEGORY" "$plist_path" 2>/dev/null || \
    "$PLIST_TOOL" -insert LSApplicationCategoryType -string "$APP_CATEGORY" "$plist_path"
  "$PLIST_TOOL" -replace NSAppleEventsUsageDescription -string "$APPLE_EVENTS_USAGE" "$plist_path" 2>/dev/null || \
    "$PLIST_TOOL" -insert NSAppleEventsUsageDescription -string "$APPLE_EVENTS_USAGE" "$plist_path"
  "$PLIST_TOOL" -replace NSHumanReadableCopyright -string "$COPYRIGHT_NOTICE" "$plist_path" 2>/dev/null || \
    "$PLIST_TOOL" -insert NSHumanReadableCopyright -string "$COPYRIGHT_NOTICE" "$plist_path"
}

update_launcher_plist "$APP_BUNDLE/Contents/Info.plist" "$APP_DISPLAY_NAME" "$APP_LAUNCHER_BUNDLE_ID"
update_launcher_plist "$STOP_APP_BUNDLE/Contents/Info.plist" "$STOP_APP_DISPLAY_NAME" "$STOP_APP_BUNDLE_ID"

echo "Built app bundle:"
echo "  $APP_BUNDLE"
echo "Built stop app bundle:"
echo "  $STOP_APP_BUNDLE"
