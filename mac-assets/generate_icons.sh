#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
RENDERER="$BUILD_DIR/icon_renderer"
SOURCE_FILE="$SCRIPT_DIR/generate_app_icons.swift"

mkdir -p "$BUILD_DIR"

/usr/bin/swiftc -parse-as-library "$SOURCE_FILE" -o "$RENDERER"

generate_iconset() {
  local base_name="$1"
  local variant="$2"
  local png_1024="$BUILD_DIR/${base_name}-1024.png"
  local icns_file="$BUILD_DIR/${base_name}.icns"

  rm -f "$icns_file"

  "$RENDERER" "$png_1024" "$variant"

  PNG_SOURCE="$png_1024" ICNS_TARGET="$icns_file" python3 - <<'PY'
from PIL import Image
import os

image = Image.open(os.environ["PNG_SOURCE"])
image.save(os.environ["ICNS_TARGET"])
PY
}

generate_iconset "AppIcon" "main"
generate_iconset "StopAppIcon" "stop"

printf 'Generated icons:\n  %s\n  %s\n' \
  "$BUILD_DIR/AppIcon.icns" \
  "$BUILD_DIR/StopAppIcon.icns"
