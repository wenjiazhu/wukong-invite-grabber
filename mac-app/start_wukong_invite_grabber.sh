#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_PAYLOAD_DIR="$SCRIPT_DIR/app"

STATIC_PORT="${WUKONG_INVITE_STATIC_PORT:-4173}"
BRIDGE_PORT="${WUKONG_INVITE_BRIDGE_PORT:-8788}"
PAGE_URL="http://127.0.0.1:${STATIC_PORT}/prototype/wukong-invite-grabber.html"

RUNTIME_ROOT="${WUKONG_INVITE_RUNTIME_ROOT:-${HOME}/Library/Application Support/WukongInviteGrabber}"
LOG_DIR="$RUNTIME_ROOT/logs"
PID_DIR="$RUNTIME_ROOT/pids"
CACHE_DIR="$RUNTIME_ROOT/cache"
STATIC_PID_FILE="$PID_DIR/static-server.pid"
BRIDGE_PID_FILE="$PID_DIR/ocr-bridge.pid"

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

mkdir -p "$LOG_DIR" "$PID_DIR" "$CACHE_DIR"

PYTHON_BIN="$(command -v python3 || true)"
if [[ -z "$PYTHON_BIN" ]]; then
  echo "python3 not found in PATH." >&2
  exit 1
fi

is_pid_running() {
  local pid="${1:-}"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" 2>/dev/null
}

read_pid_file() {
  local pid_file="$1"
  if [[ -f "$pid_file" ]]; then
    tr -d '[:space:]' < "$pid_file"
  fi
}

wait_for_http() {
  local url="$1"
  local timeout_seconds="${2:-12}"
  local start_ts
  start_ts="$(date +%s)"
  while true; do
    if /usr/bin/curl -fsS "$url" >/dev/null 2>&1; then
      return 0
    fi

    if (( "$(date +%s)" - start_ts >= timeout_seconds )); then
      return 1
    fi
    sleep 0.25
  done
}

spawn_detached() {
  local log_file="$1"
  shift

  "$PYTHON_BIN" -c '
import subprocess
import sys

log_path = sys.argv[1]
command = sys.argv[2:]
with open(log_path, "ab", buffering=0) as log_file:
    process = subprocess.Popen(
        command,
        stdin=subprocess.DEVNULL,
        stdout=log_file,
        stderr=subprocess.STDOUT,
        start_new_session=True,
        close_fds=True,
    )
print(process.pid)
' "$log_file" "$@"
}

ensure_static_server() {
  if wait_for_http "$PAGE_URL" 1; then
    return 0
  fi

  local existing_pid
  existing_pid="$(read_pid_file "$STATIC_PID_FILE")"
  if is_pid_running "$existing_pid"; then
    if wait_for_http "$PAGE_URL" 5; then
      return 0
    fi
  fi

  spawn_detached \
    "$LOG_DIR/static-server.log" \
    "$PYTHON_BIN" -m http.server "$STATIC_PORT" \
    --bind 127.0.0.1 \
    --directory "$APP_PAYLOAD_DIR" \
    > "$STATIC_PID_FILE"

  if ! wait_for_http "$PAGE_URL" 12; then
    echo "Failed to start static server on port $STATIC_PORT. Check $LOG_DIR/static-server.log" >&2
    exit 1
  fi
}

ensure_bridge() {
  local health_url="http://127.0.0.1:${BRIDGE_PORT}/health"
  if wait_for_http "$health_url" 1; then
    return 0
  fi

  local existing_pid
  existing_pid="$(read_pid_file "$BRIDGE_PID_FILE")"
  if is_pid_running "$existing_pid"; then
    if wait_for_http "$health_url" 5; then
      return 0
    fi
  fi

  spawn_detached \
    "$LOG_DIR/ocr-bridge.log" \
    /usr/bin/env WUKONG_INVITE_GRABBER_CACHE_DIR="$CACHE_DIR" \
    "$PYTHON_BIN" "$APP_PAYLOAD_DIR/prototype/tools/wukong_macos_ocr_bridge.py" \
    --host 127.0.0.1 \
    --port "$BRIDGE_PORT" \
    > "$BRIDGE_PID_FILE"

  if ! wait_for_http "$health_url" 12; then
    echo "Failed to start OCR bridge on port $BRIDGE_PORT. Check $LOG_DIR/ocr-bridge.log" >&2
    exit 1
  fi
}

ensure_static_server
ensure_bridge

if [[ "${WUKONG_INVITE_NO_OPEN:-0}" != "1" ]]; then
  /usr/bin/open "$PAGE_URL"
fi

echo "Wukong Invite Grabber is ready."
echo "Page: $PAGE_URL"
