# Wukong Invite Grabber

一个面向 `macOS` 的悟空邀请码抓取与自动填入工具仓库。

它解决的是同一条链路上的三个问题：

1. 从远端脚本拉取最新邀请码图片
2. 对图片执行中文优先 OCR，提取邀请码
3. 在本地把邀请码自动填入 `Wukong.app`，并尝试触发 `立即体验`

当前仓库同时提供三种使用方式：

- 浏览器页面 + 本地 Python bridge
- AppleScript launcher `.app`
- 原生 `Swift + WKWebView` 独立桌面 app

## 功能概览

- 动态执行远端脚本并读取返回的 `img_url`
- 手动触发 OCR，避免误识别旧图片
- 优先使用 macOS `Vision` OCR，失败时回退到浏览器侧 `Tesseract`
- 自动复制邀请码
- 自动把邀请码写入悟空 App 输入框
- 自动尝试点击 `立即体验`，失败时回退为回车提交
- 生成自定义 `.icns` 图标
- 构建独立 `.app`
- 生成更适合分发的 `.dmg`
- 支持可选的 `ad-hoc` 签名或 `Developer ID Application` 签名

## 适用范围

这个项目适用于以下场景：

- 你在 `macOS` 上手动领取或测试悟空邀请码
- 你已经能打开悟空 App，并能切到邀请码输入页
- 你希望减少“加载图片 -> OCR -> 复制/填入 -> 提交”的重复操作

已知边界：

- 当前实现只支持 `macOS`
- 自动填入依赖系统的 `辅助功能` 权限
- 自动提交逻辑依赖悟空 App 当前的无障碍树和按钮文案
- 如果悟空 App 后续升级并调整窗口结构，这部分逻辑可能需要重新适配

## 技术栈

- **Frontend**: 单文件 `HTML + CSS + JavaScript`
- **本地 OCR bridge**: `Python 3`
- **原生 OCR**: macOS `Vision`
- **原生桌面版**: `Swift + AppKit + WKWebView`
- **AppleScript launcher**: `osacompile` 打包的 `.app`
- **图标生成**: `Swift` 绘制 + `Pillow` 输出 `.icns`
- **分发打包**: `codesign` + `hdiutil`

## 目录结构

```text
.
├── README.md
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

## 环境要求

在开始之前，至少需要：

- `macOS`
- `Python 3`
- `Xcode Command Line Tools`
- 悟空 App 已打开，并停留在邀请码输入页
- 用于自动填入的宿主进程已获得 `辅助功能` 权限

安装命令行工具：

```bash
xcode-select --install
```

可选但建议具备：

- `Pillow`
  说明：当前图标生成脚本依赖 `python3` 环境中的 `PIL`

如果本机没有 `Pillow`，可先安装：

```bash
python3 -m pip install pillow
```

适用边界：

- 如果你只使用浏览器页面做 OCR，而不构建 `.app`，则不一定需要图标生成依赖
- 如果你要产出 `.dmg` 或带图标的 `.app`，建议先确认 `Pillow` 可用

## 快速开始

### 方案 A：浏览器页面 + 本地 bridge

1. 启动本地 bridge：

```bash
python3 tools/wukong_macos_ocr_bridge.py
```

2. 在仓库根目录启动静态页面：

```bash
python3 -m http.server 4173
```

3. 打开页面：

```text
http://127.0.0.1:4173/wukong-invite-grabber.html
```

4. 在页面中执行标准流程：

- 点击 `运行脚本并加载图片`
- 确认当前图片是最新邀请码图片
- 点击 `手动识别当前图片`
- 根据需要点击 `复制邀请码` 或 `填入悟空 App 并立即体验`

### 方案 B：构建 AppleScript launcher app

如果你想双击 `.app`，自动启动页面和本地 bridge：

```bash
bash mac-app/build_mac_app.sh
```

产物：

```text
mac-app/dist/Wukong Invite Grabber.app
mac-app/dist/Stop Wukong Invite Grabber.app
```

说明：

- `Wukong Invite Grabber.app` 会启动本地静态页和 OCR bridge，并自动打开页面
- `Stop Wukong Invite Grabber.app` 用来结束后台服务
- 这是轻量启动器，不是原生独立桌面应用

### 方案 C：构建原生独立 app

如果你希望页面内嵌在 app 窗口内，并且不再依赖单独启动 Python bridge：

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
- 首次启动如果被 Gatekeeper 拦截，可在 Finder 里右键 `打开`

## 分发打包

### 默认生成 `.dmg`

```bash
bash mac-standalone/package_distribution.sh
```

默认输出：

```text
mac-standalone/dist/Wukong Invite Grabber.app
mac-standalone/dist/wukong-invite-grabber-macOS-1.0.0.dmg
```

### 仅生成 app，不打 DMG

```bash
bash mac-standalone/package_distribution.sh --no-dmg
```

### ad-hoc 签名

如果当前机器没有 `Developer ID` 证书，但你仍想得到一个本地签名版本：

```bash
bash mac-standalone/package_distribution.sh --ad-hoc-sign
```

### Developer ID 签名

如果你有 Apple 开发者证书：

```bash
WUKONG_CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  bash mac-standalone/package_distribution.sh
```

分发边界：

- 仅有 `.dmg` 不代表已经被 Apple 信任
- `ad-hoc` 签名只适合本地或受控环境，不等于正式对外分发
- 如果你希望最终用户在默认 `Gatekeeper` 策略下更顺畅地打开，仍需要 `Developer ID Application`
- 如果你要进一步做到标准 Apple 分发链路，还需要额外补 `notarization`

## 使用流程

标准流程如下：

1. 打开悟空 App，并停留在邀请码输入页
2. 启动网页或 app
3. 点击 `运行脚本并加载图片`
4. 确认页面上展示的是最新邀请码图片
5. 点击 `手动识别当前图片`
6. 识别成功后：
   - 可复制邀请码
   - 可自动填入悟空 App
   - 可自动尝试点击 `立即体验`

补充说明：

- 页面不会在加载图片时自动 OCR
- 页面不会在 OCR 前自动提交
- 自动填入只有两种触发方式：
  - 勾选 `识别成功后自动填入并提交`
  - 点击 `填入悟空 App 并立即体验`

## 常见问题

### 1. 页面提示本地 bridge 未启动

执行：

```bash
python3 tools/wukong_macos_ocr_bridge.py
```

### 2. 页面提示未检测到悟空 App 进程

优先检查：

- 悟空 App 是否已经打开
- 当前是否停留在邀请码输入页
- 是否正在运行最新版本的 `tools/wukong_macos_ocr_bridge.py`
- 是否把 App 最小化到没有可见窗口

### 3. 页面提示未授予辅助功能权限

到以下位置授权：

```text
系统设置 -> 隐私与安全性 -> 辅助功能
```

根据你的启动方式放行对应宿主：

- `Terminal`
- `iTerm`
- `Codex`
- 或独立版 `Wukong Invite Grabber.app`

### 4. OCR 成功但没有自动提交

常见原因：

- 当前不在邀请码输入页
- 无障碍树没有暴露可点击按钮
- 输入焦点不正确
- 系统权限不足
- 悟空 App 升级后修改了按钮结构或文案

降级方案：

- 保留自动 OCR
- 使用 `复制邀请码`
- 手动粘贴并提交

## 诊断命令

检查 bridge 健康状态：

```bash
curl http://127.0.0.1:8788/health
```

预期返回：

```json
{"ok": true, "platform": "Darwin", "mode": "macos-vision"}
```

验证自动填入接口：

```bash
curl -X POST http://127.0.0.1:8788/fill-app \
  -H 'Content-Type: application/json' \
  --data '{"code":"灵吉定黄风","submit":true}'
```

## 项目状态

根据当前仓库内说明，最近一次本机验收结论为：

- 验收日期：`2026-03-24`
- 环境：`macOS` + 本地 bridge + 当前安装的 `Wukong.app`
- 结果：`通过`

已验证链路：

- 页面可加载最新邀请码图片
- 手动 OCR 可提取邀请码
- 本地 bridge 可连接悟空 App
- 在授权 `辅助功能` 后，可自动填入并触发 `立即体验`

## GitHub

仓库地址：

```text
https://github.com/wenjiazhu/wukong-invite-grabber
```

如果你是第一次拉取：

```bash
git clone https://github.com/wenjiazhu/wukong-invite-grabber.git
cd wukong-invite-grabber
```
