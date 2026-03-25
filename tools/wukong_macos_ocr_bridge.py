#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import json
import math
import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
TOOLS_DIR = Path(__file__).resolve().parent
CACHE_DIR = Path(os.environ.get("WUKONG_INVITE_GRABBER_CACHE_DIR", str(TOOLS_DIR / ".cache"))).expanduser()
VISION_SOURCE = TOOLS_DIR / "vision_ocr.m"
PREPROCESS_SOURCE = TOOLS_DIR / "preprocess_invite_image.m"
VISION_BINARY = CACHE_DIR / "vision_ocr"
PREPROCESS_BINARY = CACHE_DIR / "preprocess_invite_image"
CLANG_MODULE_CACHE = CACHE_DIR / "clang-module-cache"
OCR_MODES = [
    "upper_contrast",
    "upper_soft",
    "upper_thresh_240",
    "upper_thresh_245",
    "upper_wide_thresh_240",
    "upper_wide_thresh_245",
    "upper_tight_thresh_245",
]
CJK_STOP_WORDS = {
    "限量邀请码",
    "当前邀请码",
    "欢迎回来吧",
    "立即体验吧",
    "退出登录吧",
    "悟空官网获得",
    "限量",
    "已领完",
    "欢迎回来",
    "立即体验",
    "退出登录",
}
INVITE_LABEL_PATTERNS = (
    re.compile(r"当前邀请码\s*[:：]?\s*([\u4e00-\u9fff]{5})"),
    re.compile(r"邀请码\s*[:：]?\s*([\u4e00-\u9fff]{5})"),
)
CJK_FIVE_RE = re.compile(r"[\u4e00-\u9fff]{5}")
WUKONG_BUNDLE_HINTS = ("Wukong.app",)
WUKONG_PROCESS_NAME_HINTS = ("Wukong", "悟空")


def ensure_macos() -> None:
    if platform.system() != "Darwin":
        raise RuntimeError("This bridge only runs on macOS.")


def compile_helper(source_path: Path, binary_path: Path, frameworks: list[str]) -> Path:
    clang = shutil.which("clang")
    if not clang:
        raise RuntimeError("clang not found; install Xcode Command Line Tools first.")
    if not source_path.exists():
        raise RuntimeError(f"Missing source file: {source_path}")

    binary_path.parent.mkdir(parents=True, exist_ok=True)
    CLANG_MODULE_CACHE.mkdir(parents=True, exist_ok=True)

    command = [clang, "-fmodules"]
    for framework in frameworks:
        command.extend(["-framework", framework])
    command.extend([str(source_path), "-o", str(binary_path)])

    env = os.environ.copy()
    env["CLANG_MODULE_CACHE_PATH"] = str(CLANG_MODULE_CACHE)
    subprocess.run(command, check=True, env=env, capture_output=True, text=True)
    return binary_path


def ensure_binary(source_path: Path, binary_path: Path, frameworks: list[str]) -> Path:
    if binary_path.exists() and binary_path.stat().st_mtime >= source_path.stat().st_mtime:
        return binary_path
    return compile_helper(source_path, binary_path, frameworks)


def download_image(image_url: str, destination: Path) -> Path:
    parsed = urllib.parse.urlparse(image_url)
    if parsed.scheme not in {"http", "https"}:
        raise RuntimeError("image_url must use http or https.")

    request = urllib.request.Request(
        image_url,
        headers={
            "User-Agent": "wukong-macos-ocr-bridge/1.0",
            "Accept": "image/*,*/*;q=0.8",
            "Cache-Control": "no-cache",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            data = response.read()
    except urllib.error.URLError as error:
        raise RuntimeError(f"Failed to download invite image: {error}") from error

    if not data:
        raise RuntimeError("Downloaded image is empty.")

    destination.write_bytes(data)
    return destination


def decode_data_url(data_url: str, destination: Path) -> Path:
    if not data_url.startswith("data:image/"):
        raise RuntimeError("Unsupported image_data_url payload.")
    try:
        _, encoded = data_url.split(",", 1)
    except ValueError as error:
        raise RuntimeError("Malformed image_data_url payload.") from error
    destination.write_bytes(base64.b64decode(encoded))
    return destination


def run_osascript(script: str) -> str:
    try:
        result = subprocess.run(
            ["osascript", "-e", script],
            check=True,
            capture_output=True,
            text=True,
        )
    except subprocess.CalledProcessError as error:
        stderr = (error.stderr or "").strip()
        stdout = (error.stdout or "").strip()
        message = stderr or stdout or f"osascript exited with code {error.returncode}."
        raise RuntimeError(message) from error
    return result.stdout.strip()


def read_process_command(pid: int) -> str:
    if pid <= 0:
        return ""
    try:
        result = subprocess.run(
            ["ps", "-o", "command=", "-p", str(pid)],
            check=True,
            capture_output=True,
            text=True,
        )
    except (PermissionError, subprocess.CalledProcessError):
        return ""
    return result.stdout.strip()


def extract_app_bundle_path(command: str) -> str:
    if not command:
        return ""
    match = re.search(r"(/.*?\.app)", command)
    return match.group(1) if match else ""


def probe_system_events_access() -> dict[str, object]:
    script = 'tell application "System Events" to count of application processes'
    try:
        detail = run_osascript(script)
        return {
            "ok": True,
            "detail": detail,
        }
    except RuntimeError as error:
        return {
            "ok": False,
            "detail": str(error),
        }


def build_bridge_diagnostics() -> dict[str, object]:
    runner_pid = os.getpid()
    parent_pid = os.getppid()
    runner_executable = sys.executable
    parent_command = read_process_command(parent_pid)
    parent_app_path = extract_app_bundle_path(parent_command)

    permission_target_path = parent_app_path or runner_executable
    if parent_app_path:
        permission_target_label = Path(parent_app_path).stem
    elif parent_command:
        permission_target_label = Path(parent_command.split()[0]).name
    else:
        permission_target_label = Path(runner_executable).name or "python3"

    return {
        "runner_type": "python-bridge",
        "runner_pid": runner_pid,
        "runner_executable": runner_executable,
        "parent_pid": parent_pid,
        "parent_command": parent_command,
        "permission_target_label": permission_target_label,
        "permission_target_path": permission_target_path,
        "system_events_probe": probe_system_events_access(),
    }


def applescript_quote(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def resolve_wukong_process_name() -> str:
    script = """
    tell application "System Events"
        repeat with proc in application processes
            set procName to name of proc as text
            if procName contains "Wukong" or procName contains "悟空" then
                return procName
            end if
        end repeat
    end tell
    return ""
    """
    try:
        return run_osascript(script)
    except RuntimeError:
        # Listing application processes via System Events can fail in tighter
        # automation environments even when the app is actually running.
        # Fall back to bundle-path matching from `ps`.
        return ""


def find_wukong_pid_from_ps() -> int | None:
    try:
        result = subprocess.run(
            ["ps", "-ax", "-o", "pid=", "-o", "command="],
            check=True,
            capture_output=True,
            text=True,
        )
    except PermissionError as error:
        raise RuntimeError("Unable to inspect the macOS process list for Wukong.app.") from error
    except subprocess.CalledProcessError as error:
        stderr = (error.stderr or "").strip()
        stdout = (error.stdout or "").strip()
        message = stderr or stdout or f"ps exited with code {error.returncode}."
        raise RuntimeError(message) from error

    candidates: list[tuple[int, str]] = []
    for raw_line in result.stdout.splitlines():
        line = raw_line.strip()
        if not line:
            continue

        parts = line.split(None, 1)
        if len(parts) != 2:
            continue

        pid_text, command = parts
        try:
            pid = int(pid_text)
        except ValueError:
            continue

        bundle_hit = any(f"/{bundle_hint}/" in command for bundle_hint in WUKONG_BUNDLE_HINTS)
        if not bundle_hit:
            continue

        # Ignore sidecar helpers and internal service binaries. We want the main
        # app host process that owns the visible window tree.
        if "/Contents/Resources/" in command:
            continue
        if "crashpad_handler" in command or "real_networking" in command:
            continue

        candidates.append((pid, command))

    if not candidates:
        return None

    candidates.sort(key=lambda item: item[0])
    return candidates[0][0]


def resolve_wukong_target() -> dict[str, object]:
    process_name = resolve_wukong_process_name()
    if process_name:
        return {
            "process_name": process_name,
            "unix_id": None,
            "match_strategy": "application-process-name",
        }

    unix_id = find_wukong_pid_from_ps()
    if unix_id is not None:
        return {
            "process_name": None,
            "unix_id": unix_id,
            "match_strategy": "bundle-path-from-ps",
        }

    raise RuntimeError("Wukong app process not found. Open the app first and keep it on the invite page.")


def fill_wukong_app(code: str, submit: bool = True) -> dict[str, object]:
    ensure_macos()
    if not code.strip():
        raise RuntimeError("Invite code is empty.")

    invite_code = code.strip()
    target = resolve_wukong_target()
    process_name = target.get("process_name")
    unix_id = target.get("unix_id")
    submit_flag = "true" if submit else "false"
    if isinstance(process_name, str) and process_name:
        process_selector = f'first application process whose name is {applescript_quote(process_name)}'
    elif isinstance(unix_id, int):
        process_selector = f"first application process whose unix id is {unix_id}"
    else:
        raise RuntimeError("Unable to resolve Wukong app target process.")

    script = f"""
    on findFirstInput(targetWindow)
        tell application "System Events"
            set uiItems to entire contents of targetWindow
            repeat with uiItem in uiItems
                try
                    set uiRole to role of uiItem as text
                    if uiRole is "AXTextField" or uiRole is "AXTextArea" or uiRole is "AXComboBox" then
                        return uiItem
                    end if
                end try
            end repeat
        end tell
        return missing value
    end findFirstInput

    on clickSubmitButton(targetWindow)
        tell application "System Events"
            set uiItems to entire contents of targetWindow
            repeat with uiItem in uiItems
                try
                    if (role of uiItem as text) is "AXButton" then
                        set buttonName to ""
                        try
                            set buttonName to name of uiItem as text
                        end try
                        if buttonName contains "立即体验" then
                            click uiItem
                            return true
                        end if
                    end if
                end try
            end repeat
        end tell
        return false
    end clickSubmitButton

    on focusInput(targetInput)
        if targetInput is missing value then
            return false
        end if

        tell application "System Events"
            try
                perform action "AXPress" of targetInput
            end try
            try
                set focused of targetInput to true
            end try
        end tell
        delay 0.15
        return true
    end focusInput

    on replaceTextByPaste(targetInput, inviteCode)
        set clipboardBackup to missing value
        set hasClipboardBackup to false

        my focusInput(targetInput)

        try
            set clipboardBackup to the clipboard
            set hasClipboardBackup to true
        end try
        set the clipboard to inviteCode

        tell application "System Events"
            keystroke "a" using command down
            delay 0.08
            key code 51
            delay 0.08
            keystroke "v" using command down
        end tell
        delay 0.18

        if hasClipboardBackup then
            set the clipboard to clipboardBackup
        end if

        return "clipboard-paste"
    end replaceTextByPaste

    on fillInviteCode(targetInput, inviteCode)
        tell application "System Events"
            if targetInput is not missing value then
                try
                    set value of targetInput to inviteCode
                    return "set-value"
                end try
            end if
        end tell

        my focusInput(targetInput)

        tell application "System Events"
            if targetInput is not missing value then
                try
                    set value of targetInput to inviteCode
                    return "focused-set-value"
                end try
            end if
        end tell

        try
            return my replaceTextByPaste(targetInput, inviteCode)
        on error
            my focusInput(targetInput)
            tell application "System Events"
                keystroke "a" using command down
                delay 0.08
                key code 51
                delay 0.08
                keystroke inviteCode
            end tell
            delay 0.18
        end try
        return "keystroke"
    end fillInviteCode

    set inviteCode to {applescript_quote(invite_code)}
    set shouldSubmit to {submit_flag}
    set targetWindow to missing value
    set clickedSubmit to false
    set fillMethod to "unknown"

    tell application "System Events"
        set targetProcess to {process_selector}
        tell targetProcess
            set frontmost to true
        end tell
    end tell
    delay 0.6

    tell application "System Events"
        tell targetProcess
            if (count of windows) is 0 then
                error "Wukong app has no visible window."
            end if
            set frontmost to true
            set targetWindow to front window
            set targetInput to my findFirstInput(targetWindow)
            my focusInput(targetInput)
        end tell

        set fillMethod to my fillInviteCode(targetInput, inviteCode)
        delay 0.35

        if shouldSubmit then
            set clickedSubmit to my clickSubmitButton(targetWindow)
            if clickedSubmit is false then
                keystroke return
            end if
        end if
    end tell

    if clickedSubmit then
        return "button"
    end if

    if shouldSubmit then
        return "return"
    end if

    return fillMethod
    """
    fill_method = run_osascript(script) or "unknown"
    return {
        "ok": True,
        "process_name": process_name,
        "unix_id": unix_id,
        "submitted": submit,
        "mode": "ui-script",
        "fill_method": fill_method,
        "match_strategy": target.get("match_strategy"),
    }


def run_preprocess(binary_path: Path, input_path: Path, output_path: Path, mode: str) -> Path:
    subprocess.run(
        [str(binary_path), str(input_path), str(output_path), mode],
        check=True,
        capture_output=True,
        text=True,
    )
    return output_path


def run_vision(binary_path: Path, image_path: Path) -> str:
    result = subprocess.run(
        [str(binary_path), str(image_path)],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def has_cjk(text: str) -> bool:
    return any("\u4e00" <= char <= "\u9fff" for char in text)


def score_chinese_candidate(candidate: str) -> float:
    score = 0.0
    if 4 <= len(candidate) <= 6:
        score += 8
    elif 3 <= len(candidate) <= 8:
        score += 4
    if has_cjk(candidate):
        score += 5
    if len(candidate) == 5:
        score += 2
    if re.search(r"邀请码|当前|已领完|限量|领取|今日|剩余", candidate):
        score -= 10
    return score


def extract_best_candidate(text: str) -> tuple[str, float]:
    normalized = (
        text.replace("\u3000", " ")
        .replace("\r\n", "\n")
        .replace("\r", "\n")
        .strip()
    )
    for pattern in INVITE_LABEL_PATTERNS:
        match = pattern.search(normalized)
        if match:
            candidate = match.group(1).strip()
            return candidate, score_chinese_candidate(candidate) + 6

    exact_five = []
    for token in CJK_FIVE_RE.findall(normalized):
        if token in CJK_STOP_WORDS:
            continue
        if token not in exact_five:
            exact_five.append(token)
    if len(exact_five) == 1:
        candidate = exact_five[0]
        return candidate, score_chinese_candidate(candidate) + 4

    ranked = []
    seen = set()
    compact_lines = [
        line.replace(" ", "").replace("\t", "").strip()
        for line in normalized.split("\n")
        if line.strip()
    ]
    for raw_line in compact_lines:
        line = (
            raw_line.replace("当前邀请码", "")
            .replace("邀请码", "")
            .replace("已领完", "")
            .replace("限量", "")
        )
        matches = re.findall(r"[\u4e00-\u9fff]{3,10}", line)
        for candidate in [line, *matches]:
            candidate = candidate.strip()
            if not candidate or candidate in seen or candidate in CJK_STOP_WORDS:
                continue
            seen.add(candidate)
            score = score_chinese_candidate(candidate)
            if score > 0:
                ranked.append((candidate, score))

    if ranked:
        ranked.sort(key=lambda item: (-item[1], len(item[0])))
        return ranked[0]

    return "", float("-inf")


def json_safe_score(score: float) -> float | None:
    return score if math.isfinite(score) else None


def json_safe_records(records: list[dict[str, object]]) -> list[dict[str, object]]:
    safe_records = []
    for record in records:
        safe_record = dict(record)
        score = safe_record.get("score")
        if isinstance(score, (int, float)):
            safe_record["score"] = json_safe_score(float(score))
        safe_records.append(safe_record)
    return safe_records


def run_native_ocr(image_url: str, variants: list[object] | None = None) -> dict[str, object]:
    ensure_macos()
    vision_binary = ensure_binary(VISION_SOURCE, VISION_BINARY, ["Foundation", "Vision", "AppKit"])

    runtime_dir = CACHE_DIR / "runtime"
    runtime_dir.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="wukong-macos-ocr-", dir=runtime_dir) as temp_dir_name:
        temp_dir = Path(temp_dir_name)
        best_record = {
            "label": "original",
            "candidate": "",
            "raw_text": "",
            "score": float("-inf"),
        }
        records = []

        def evaluate_candidate(label: str, image_path: Path) -> bool:
            nonlocal best_record
            raw_text = run_vision(vision_binary, image_path)
            candidate, score = extract_best_candidate(raw_text)
            record = {
                "label": label,
                "candidate": candidate,
                "raw_text": raw_text,
                "score": score,
            }
            records.append(record)
            if score > best_record["score"]:
                best_record = record
            return bool(candidate and re.fullmatch(r"[\u4e00-\u9fff]{5}", candidate))

        if variants:
            for index, variant in enumerate(variants):
                if not isinstance(variant, dict):
                    continue
                data_url = variant.get("image_data_url")
                label = variant.get("label")
                if not isinstance(data_url, str) or not data_url:
                    continue
                variant_path = decode_data_url(
                    data_url,
                    temp_dir / f"browser-variant-{index}.png",
                )
                try:
                    if evaluate_candidate(
                        label if isinstance(label, str) and label else f"browser-variant-{index + 1}",
                        variant_path,
                    ):
                        return {
                            "candidate": best_record["candidate"],
                            "raw_text": best_record["raw_text"],
                            "label": f"macOS Vision OCR · {best_record['label']}",
                            "score": json_safe_score(best_record["score"]),
                            "records": json_safe_records(records),
                        }
                except subprocess.CalledProcessError:
                    continue

        preprocess_binary = ensure_binary(PREPROCESS_SOURCE, PREPROCESS_BINARY, ["Foundation", "AppKit"])
        original_path = download_image(image_url, temp_dir / "invite-image")
        candidates: list[tuple[str, Path]] = [("original", original_path)]
        for mode in OCR_MODES:
            output_path = temp_dir / f"{mode}.png"
            run_preprocess(preprocess_binary, original_path, output_path, mode)
            candidates.append((mode, output_path))

        for label, image_path in candidates:
            try:
                if evaluate_candidate(label, image_path):
                    # Impossible to improve upon a perfect 5-char candidate from one pass.
                    break
            except subprocess.CalledProcessError:
                continue

        return {
            "candidate": best_record["candidate"],
            "raw_text": best_record["raw_text"],
            "label": f"macOS Vision OCR · {best_record['label']}",
            "score": json_safe_score(best_record["score"]),
            "records": json_safe_records(records),
        }


class OCRBridgeHandler(BaseHTTPRequestHandler):
    server_version = "WukongMacOCRBridge/1.0"

    def end_headers(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, format: str, *args: object) -> None:
        return

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self.end_headers()

    def do_GET(self) -> None:
        if self.path.startswith("/health"):
            payload = {
                "ok": True,
                "platform": platform.system(),
                "mode": "macos-vision",
                "diagnostics": build_bridge_diagnostics(),
            }
            self.respond_json(200, payload)
            return
        self.respond_json(404, {"error": "Not found."})

    def do_POST(self) -> None:
        if self.path == "/fill-app":
            self.handle_fill_app()
            return
        if self.path != "/ocr":
            self.respond_json(404, {"error": "Not found."})
            return

        try:
            content_length = int(self.headers.get("Content-Length", "0"))
            raw_body = self.rfile.read(content_length)
            payload = json.loads(raw_body.decode("utf-8") or "{}")
        except (ValueError, json.JSONDecodeError):
            self.respond_json(400, {"error": "Invalid JSON body."})
            return

        image_url = payload.get("image_url")
        if not isinstance(image_url, str) or not image_url.strip():
            self.respond_json(400, {"error": "image_url is required."})
            return

        try:
            variants = payload.get("variants")
            if variants is not None and not isinstance(variants, list):
                self.respond_json(400, {"error": "variants must be an array when provided."})
                return
            result = run_native_ocr(image_url.strip(), variants if isinstance(variants, list) else None)
        except subprocess.CalledProcessError as error:
            stderr = (error.stderr or "").strip()
            stdout = (error.stdout or "").strip()
            message = stderr or stdout or "Native OCR helper failed."
            self.respond_json(500, {"error": message})
            return
        except Exception as error:  # noqa: BLE001
            self.respond_json(500, {"error": str(error)})
            return

        self.respond_json(200, result)

    def handle_fill_app(self) -> None:
        try:
            content_length = int(self.headers.get("Content-Length", "0"))
            raw_body = self.rfile.read(content_length)
            payload = json.loads(raw_body.decode("utf-8") or "{}")
        except (ValueError, json.JSONDecodeError):
            self.respond_json(400, {"error": "Invalid JSON body."})
            return

        code = payload.get("code")
        submit = payload.get("submit", True)
        if not isinstance(code, str) or not code.strip():
            self.respond_json(400, {"error": "code is required."})
            return
        if not isinstance(submit, bool):
            self.respond_json(400, {"error": "submit must be a boolean when provided."})
            return

        try:
            result = fill_wukong_app(code.strip(), submit)
        except subprocess.CalledProcessError as error:
            stderr = (error.stderr or "").strip()
            stdout = (error.stdout or "").strip()
            message = stderr or stdout or str(error) or "fill-app command failed."
            self.respond_json(500, {"error": message, "diagnostics": build_bridge_diagnostics()})
            return
        except Exception as error:  # noqa: BLE001
            self.respond_json(500, {"error": str(error), "diagnostics": build_bridge_diagnostics()})
            return

        self.respond_json(200, result)

    def respond_json(self, status_code: int, payload: dict[str, object]) -> None:
        encoded = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Local macOS Vision OCR bridge for wukong-invite-grabber.html")
    parser.add_argument("--host", default="127.0.0.1", help="Bind host. Default: 127.0.0.1")
    parser.add_argument("--port", type=int, default=8788, help="Bind port. Default: 8788")
    return parser.parse_args()


def main() -> int:
    ensure_macos()
    args = parse_args()
    server = ThreadingHTTPServer((args.host, args.port), OCRBridgeHandler)
    print(f"Wukong macOS OCR bridge listening on http://{args.host}:{args.port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping bridge...")
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
