#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"
source "$PROJECT_ROOT/mac-assets/app_metadata.sh"

APP_BUNDLE="$DIST_DIR/$APP_NAME"
DMG_PATH="$DIST_DIR/${APP_SLUG}-macOS-${APP_VERSION}.dmg"
STAGING_DIR="$DIST_DIR/dmg-staging"

SIGN_IDENTITY="${WUKONG_CODESIGN_IDENTITY:-}"
ADHOC_SIGN=0
SKIP_DMG=0
SKIP_BUILD=0

usage() {
  cat <<EOF
Usage: bash mac-standalone/package_distribution.sh [options]

Options:
  --sign "<Developer ID Application: ...>"  Sign the app with the provided identity.
  --ad-hoc-sign                             Apply an ad-hoc signature when no Developer ID is available.
  --no-dmg                                  Skip DMG creation and only build/sign the app bundle.
  --skip-build                              Reuse the existing app bundle in dist/ without rebuilding it.
  -h, --help                                Show this help message.

Environment:
  WUKONG_CODESIGN_IDENTITY                  Same as --sign.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sign)
      [[ $# -ge 2 ]] || { echo "Missing value for --sign" >&2; exit 1; }
      SIGN_IDENTITY="$2"
      shift 2
      ;;
    --ad-hoc-sign)
      ADHOC_SIGN=1
      shift
      ;;
    --no-dmg)
      SKIP_DMG=1
      shift
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "$ADHOC_SIGN" == "1" && -n "$SIGN_IDENTITY" ]]; then
  echo "Use either --sign or --ad-hoc-sign, not both." >&2
  exit 1
fi

if [[ "$SKIP_BUILD" != "1" ]]; then
  bash "$SCRIPT_DIR/build_standalone_mac_app.sh"
fi

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "App bundle not found: $APP_BUNDLE" >&2
  exit 1
fi

sign_app() {
  local target="$1"
  local identity="$2"
  local -a sign_args=(--force --deep --sign "$identity")

  if [[ "$identity" != "-" ]]; then
    sign_args+=(--options runtime --timestamp)
  fi

  /usr/bin/codesign "${sign_args[@]}" "$target"
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$target"
}

SIGNING_STATE="unsigned"
if [[ -n "$SIGN_IDENTITY" ]]; then
  sign_app "$APP_BUNDLE" "$SIGN_IDENTITY"
  SIGNING_STATE="developer-id-signed"
elif [[ "$ADHOC_SIGN" == "1" ]]; then
  sign_app "$APP_BUNDLE" "-"
  SIGNING_STATE="ad-hoc-signed"
fi

if [[ "$SKIP_DMG" != "1" ]]; then
  rm -rf "$STAGING_DIR" "$DMG_PATH"
  mkdir -p "$STAGING_DIR"

  /usr/bin/ditto "$APP_BUNDLE" "$STAGING_DIR/$APP_NAME"
  ln -s /Applications "$STAGING_DIR/Applications"

  /usr/bin/hdiutil create \
    -volname "$DMG_VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -format UDZO \
    -ov \
    "$DMG_PATH" >/dev/null

  if [[ -n "$SIGN_IDENTITY" ]]; then
    /usr/bin/codesign --force --sign "$SIGN_IDENTITY" "$DMG_PATH"
    /usr/bin/codesign --verify --verbose=2 "$DMG_PATH"
  fi
fi

echo "Distribution artifacts are ready."
echo "App bundle: $APP_BUNDLE"
echo "Signing state: $SIGNING_STATE"
if [[ "$SKIP_DMG" != "1" ]]; then
  echo "DMG: $DMG_PATH"
fi
