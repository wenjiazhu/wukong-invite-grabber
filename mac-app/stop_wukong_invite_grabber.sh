#!/usr/bin/env bash
set -euo pipefail

RUNTIME_ROOT="${WUKONG_INVITE_RUNTIME_ROOT:-${HOME}/Library/Application Support/WukongInviteGrabber}"
PID_DIR="$RUNTIME_ROOT/pids"
STATIC_PID_FILE="$PID_DIR/static-server.pid"
BRIDGE_PID_FILE="$PID_DIR/ocr-bridge.pid"

is_pid_running() {
  local pid="${1:-}"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" 2>/dev/null
}

stop_from_pid_file() {
  local pid_file="$1"
  if [[ ! -f "$pid_file" ]]; then
    return 0
  fi

  local pid
  pid="$(tr -d '[:space:]' < "$pid_file")"
  if is_pid_running "$pid"; then
    kill "$pid" 2>/dev/null || true
    sleep 0.5
    if is_pid_running "$pid"; then
      kill -9 "$pid" 2>/dev/null || true
    fi
  fi

  rm -f "$pid_file"
}

stop_from_pid_file "$STATIC_PID_FILE"
stop_from_pid_file "$BRIDGE_PID_FILE"

echo "Wukong Invite Grabber background services stopped."
