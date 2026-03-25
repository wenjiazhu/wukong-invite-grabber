# Wukong Invite Grabber

![Platform](https://img.shields.io/badge/platform-macOS-111827?logo=apple&logoColor=white)
![Standalone](https://img.shields.io/badge/standalone-Swift%20%2B%20WKWebView-F05138?logo=swift&logoColor=white)
![Bridge](https://img.shields.io/badge/bridge-Python%203-3776AB?logo=python&logoColor=white)
![Distribution](https://img.shields.io/badge/distribution-app%20%7C%20dmg%20%7C%20zip-0f766e)
![Version](https://img.shields.io/badge/version-v1.0.0-f59e0b)

一个面向 `macOS` 的悟空邀请码抓取与自动填入工具。  
A macOS-focused utility for fetching Wukong invite-code images, running OCR, and filling the recognized code back into `Wukong.app`.

![Wukong Invite Grabber overview](docs/images/github-overview.png)

## 中文

### 项目简介

这个仓库把“拉图 -> OCR -> 复制/填入 -> 提交”这条链路拆成三个可组合的交付形态：

- 浏览器页面 + 本地 Python bridge
- AppleScript launcher `.app`
- 原生 `Swift + WKWebView` 独立桌面 app

核心能力：

- 动态执行远端脚本并读取返回的 `img_url`
- 手动触发 OCR，避免识别旧图
- 优先使用 macOS `Vision` OCR，失败时回退到浏览器侧 `Tesseract`
- 自动复制邀请码
- 自动把邀请码写入悟空 App 输入框
- 自动尝试点击 `立即体验`，失败时回退为回车提交
- 生成自定义 `.icns` 图标
- 生成独立 `.app`
- 生成 `.dmg` 与可上传的 `.app.zip`

### 环境要求

- `macOS`
- `Python 3`
- `Xcode Command Line Tools`
- 已打开 `Wukong.app` 并切到邀请码输入页
- 用于自动填入的宿主进程已获得 `辅助功能` 权限

安装命令行工具：

```bash
xcode-select --install
```

图标生成脚本依赖 `Pillow`。如果本机没有 `PIL`，先执行：

```bash
python3 -m pip install pillow
```

### 快速开始

#### 1. 浏览器页面 + 本地 bridge

启动 bridge：

```bash
python3 tools/wukong_macos_ocr_bridge.py
```

启动静态页面：

```bash
python3 -m http.server 4173
```

打开页面：

```text
http://127.0.0.1:4173/wukong-invite-grabber.html
```

标准操作流程：

1. 点击 `运行脚本并加载图片`
2. 确认当前图片是最新邀请码图片
3. 点击 `手动识别当前图片`
4. 根据需要点击 `复制邀请码` 或 `填入悟空 App 并立即体验`

#### 2. AppleScript launcher app

如果你要一个可以双击启动页面和 bridge 的启动器：

```bash
bash mac-app/build_mac_app.sh
```

产物：

```text
mac-app/dist/Wukong Invite Grabber.app
mac-app/dist/Stop Wukong Invite Grabber.app
```

说明：

- `Wukong Invite Grabber.app` 负责启动静态页和 OCR bridge
- `Stop Wukong Invite Grabber.app` 用来结束后台服务
- 这是 launcher，不是原生独立桌面应用

#### 3. 原生独立 app

如果你要一个不依赖系统浏览器、也不需要单独启动 Python bridge 的原生桌面版：

```bash
bash mac-standalone/build_standalone_mac_app.sh
```

产物：

```text
mac-standalone/dist/Wukong Invite Grabber.app
```

说明：

- 内部使用 `WKWebView` 加载前端页面
- OCR 与自动填入由 app 内置原生桥接处理
- 首次打开若被 Gatekeeper 拦截，可在 Finder 中右键 `打开`

#### 4. 分发打包

默认构建分发包：

```bash
bash mac-standalone/package_distribution.sh
```

默认输出：

```text
mac-standalone/dist/Wukong Invite Grabber.app
mac-standalone/dist/wukong-invite-grabber-macOS-1.0.0.dmg
```

`ad-hoc` 签名：

```bash
bash mac-standalone/package_distribution.sh --ad-hoc-sign
```

`Developer ID` 签名：

```bash
WUKONG_CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  bash mac-standalone/package_distribution.sh
```

### Release 资产

本仓库的 release 目标资产为：

- `wukong-invite-grabber-macOS-1.0.0.dmg`
- `wukong-invite-grabber-macOS-1.0.0.app.zip`

当前 release：

- [v1.0.0](https://github.com/wenjiazhu/wukong-invite-grabber/releases/tag/v1.0.0)

适用边界：

- `ad-hoc` 签名只适合本地或受控环境
- `.dmg` 本身不代表已经被 Apple 信任
- 如果你希望最终用户在默认 `Gatekeeper` 策略下顺畅打开，仍需要 `Developer ID Application` 证书
- 若要做标准 Apple 分发链路，还需要继续补 `notarization`

### 目录结构

```text
.
├── README.md
├── docs/images/github-overview.png
├── wukong-invite-grabber.html
├── wukong-invite-grabber-usage.md
├── tools/
│   ├── wukong_macos_ocr_bridge.py
│   ├── vision_ocr.m
│   └── preprocess_invite_image.m
├── mac-app/
│   ├── build_mac_app.sh
│   ├── start_wukong_invite_grabber.sh
│   ├── stop_wukong_invite_grabber.sh
│   ├── Wukong Invite Grabber.applescript
│   └── Stop Wukong Invite Grabber.applescript
├── mac-standalone/
│   ├── WukongInviteGrabberStandalone.swift
│   ├── build_standalone_mac_app.sh
│   └── package_distribution.sh
└── mac-assets/
    ├── app_metadata.sh
    ├── generate_app_icons.swift
    └── generate_icons.sh
```

### 已知限制

- 当前实现只支持 `macOS`
- 自动填入依赖系统 `辅助功能` 权限
- 自动提交逻辑依赖悟空 App 当前无障碍树和按钮文案
- 如果悟空 App 升级并修改窗口结构，这部分逻辑可能需要重新适配

### 诊断命令

检查 bridge 健康状态：

```bash
curl http://127.0.0.1:8788/health
```

验证自动填入接口：

```bash
curl -X POST http://127.0.0.1:8788/fill-app \
  -H 'Content-Type: application/json' \
  --data '{"code":"灵吉定黄风","submit":true}'
```

---

## English

### Overview

This repository packages the same workflow into three deliverables:

- Browser page + local Python bridge
- AppleScript launcher `.app`
- Native `Swift + WKWebView` standalone desktop app

Core capabilities:

- Execute a remote script and read its `img_url`
- Trigger OCR manually to avoid processing stale images
- Prefer macOS `Vision` OCR and fall back to browser-side `Tesseract`
- Copy the recognized invite code
- Fill the code into `Wukong.app`
- Attempt to click `立即体验`, then fall back to the Return key if needed
- Generate custom `.icns` icons
- Build a standalone `.app`
- Build `.dmg` and uploadable `.app.zip` release assets

### Requirements

- `macOS`
- `Python 3`
- `Xcode Command Line Tools`
- `Wukong.app` already open on the invite-code input screen
- Accessibility permission granted to the host process that performs automation

Install command-line tools:

```bash
xcode-select --install
```

The icon-generation flow depends on `Pillow`:

```bash
python3 -m pip install pillow
```

### Quick Start

#### 1. Browser page + local bridge

Start the bridge:

```bash
python3 tools/wukong_macos_ocr_bridge.py
```

Start the static page:

```bash
python3 -m http.server 4173
```

Open:

```text
http://127.0.0.1:4173/wukong-invite-grabber.html
```

Recommended flow:

1. Click `运行脚本并加载图片`
2. Confirm that the displayed image is the latest invite image
3. Click `手动识别当前图片`
4. Use `复制邀请码` or `填入悟空 App 并立即体验`

#### 2. AppleScript launcher app

Build the launcher apps:

```bash
bash mac-app/build_mac_app.sh
```

Artifacts:

```text
mac-app/dist/Wukong Invite Grabber.app
mac-app/dist/Stop Wukong Invite Grabber.app
```

#### 3. Native standalone app

Build the native desktop app:

```bash
bash mac-standalone/build_standalone_mac_app.sh
```

Artifact:

```text
mac-standalone/dist/Wukong Invite Grabber.app
```

#### 4. Distribution package

Build the default distribution package:

```bash
bash mac-standalone/package_distribution.sh
```

Artifacts:

```text
mac-standalone/dist/Wukong Invite Grabber.app
mac-standalone/dist/wukong-invite-grabber-macOS-1.0.0.dmg
```

Ad-hoc signing:

```bash
bash mac-standalone/package_distribution.sh --ad-hoc-sign
```

Developer ID signing:

```bash
WUKONG_CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  bash mac-standalone/package_distribution.sh
```

### Release Assets

The intended release assets are:

- `wukong-invite-grabber-macOS-1.0.0.dmg`
- `wukong-invite-grabber-macOS-1.0.0.app.zip`

Current release:

- [v1.0.0](https://github.com/wenjiazhu/wukong-invite-grabber/releases/tag/v1.0.0)

Distribution boundaries:

- `ad-hoc` signing is suitable for local or controlled environments only
- A `.dmg` alone is not equivalent to Apple-trusted distribution
- Smooth default `Gatekeeper` trust still requires a valid `Developer ID Application` certificate
- Full Apple-style distribution still needs notarization

### Repository Layout

```text
.
├── README.md
├── docs/images/github-overview.png
├── wukong-invite-grabber.html
├── wukong-invite-grabber-usage.md
├── tools/
├── mac-app/
├── mac-standalone/
└── mac-assets/
```

### Known Limitations

- macOS only
- Automation depends on Accessibility permission
- Auto-submit depends on the current accessibility tree and button labels inside `Wukong.app`
- If the Wukong app changes its UI structure, automation may require rework

### Diagnostics

Health check:

```bash
curl http://127.0.0.1:8788/health
```

Fill-app endpoint test:

```bash
curl -X POST http://127.0.0.1:8788/fill-app \
  -H 'Content-Type: application/json' \
  --data '{"code":"灵吉定黄风","submit":true}'
```

## Repository

GitHub:

```text
https://github.com/wenjiazhu/wukong-invite-grabber
```
