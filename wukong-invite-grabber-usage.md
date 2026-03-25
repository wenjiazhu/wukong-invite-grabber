# 悟空邀请码抓取页使用说明

## 0. 当前状态

截至 `2026-03-24`，以下链路已在当前机器上完成实测：

- 页面可成功加载最新邀请码图片
- 手动 OCR 可成功提取邀请码
- 本地 macOS bridge 可成功连接悟空 App
- 在授予 macOS `辅助功能` 权限后，邀请码可自动填入悟空 App，并可触发 `立即体验`

适用边界：

- 当前结论基于本机当前安装的 `Wukong.app`
- 当前 bridge 已兼容 `Wukong.app` 实际主进程名不是 `Wukong`、而是 `DingTalkReal` 的情况
- 若后续悟空 App 升级并修改窗口结构、按钮文案或无障碍树，自动点击逻辑可能需要再次调整

## 1. 适用范围

本说明适用于：

- 本仓库中的页面：[`./wukong-invite-grabber.html`](./wukong-invite-grabber.html)
- 本地 macOS OCR / 自动填入 bridge：[`./tools/wukong_macos_ocr_bridge.py`](./tools/wukong_macos_ocr_bridge.py)

目标能力包括：

- 运行远端脚本并加载最新邀请码图片
- 手动触发 OCR，避免误识别旧图
- 在 macOS 上自动将邀请码填入悟空 App，并尝试点击“立即体验”

## 2. 前置条件

需要满足以下条件：

- 操作系统为 `macOS`
- 已安装 `Python 3`
- 已安装 `Xcode Command Line Tools`
- 悟空 App 已打开，并停留在邀请码输入页
- 当前终端或 Python 已获得 macOS `辅助功能` 权限

如果没有安装命令行工具，可先执行：

```bash
xcode-select --install
```

## 3. 启动方式

### 3.1 启动本地 bridge

在仓库根目录执行：

```bash
python3 tools/wukong_macos_ocr_bridge.py
```

正常启动后会看到类似输出：

```text
Wukong macOS OCR bridge listening on http://127.0.0.1:8788
```

如果你之前已经启动过旧版本 bridge，更新代码后必须先停掉旧进程，再重新启动；否则页面仍可能命中旧逻辑。

### 3.2 启动静态页面

建议使用本地 HTTP 服务打开原型页，而不是直接双击 HTML 文件：

```bash
python3 -m http.server 4173
```

然后在浏览器访问：

```text
http://127.0.0.1:4173/wukong-invite-grabber.html
```

### 3.3 构建 mac app

如果你希望直接双击 `.app` 启动，而不是手动跑命令，可在仓库根目录执行：

```bash
bash mac-app/build_mac_app.sh
```

构建完成后，产物位于：

```text
mac-app/dist/Wukong Invite Grabber.app
mac-app/dist/Stop Wukong Invite Grabber.app
```

说明：

- `Wukong Invite Grabber.app`：启动本地静态页与 macOS bridge，并打开抓取页
- `Stop Wukong Invite Grabber.app`：停止上述后台服务
- 当前打包方案不会引入 Electron；它会把页面和 Python bridge 打进 `.app` 的资源目录，再由 AppleScript app 壳启动
- 两个 launcher app 都会自动使用仓库内置的自定义 `.icns` 图标

### 3.4 构建独立 mac app

如果你要一个不依赖系统浏览器、也不需要单独启动 bridge 的独立桌面 app，可在仓库根目录执行：

```bash
bash mac-standalone/build_standalone_mac_app.sh
```

构建完成后，产物位于：

```text
mac-standalone/dist/Wukong Invite Grabber.app
```

说明：

- 这是原生 `Swift + WKWebView` 桌面 app
- 页面直接内嵌在 app 窗口内，不再依赖外部浏览器
- OCR 与悟空 App 自动填入由 app 内置原生 bridge 直接处理，不再依赖单独的本地 Python bridge 服务
- 首次使用时，仍然需要在 macOS 里给该 app 授予 `辅助功能` 权限，否则无法自动填入悟空 App
- 如果 macOS 因为未签名而拦截首次启动，可在 Finder 中右键该 app，选择“打开”
- 独立 app 会自动带上仓库内置的自定义图标

### 3.5 构建正式分发包

如果你要生成更适合分发的产物，优先使用独立版 app 的分发脚本：

```bash
bash mac-standalone/package_distribution.sh
```

默认输出：

```text
mac-standalone/dist/Wukong Invite Grabber.app
mac-standalone/dist/wukong-invite-grabber-macOS-1.0.0.dmg
```

可选模式：

```bash
# 没有 Developer ID 证书时，给 app 做 ad-hoc 签名
bash mac-standalone/package_distribution.sh --ad-hoc-sign

# 有 Developer ID 证书时，生成签名后的 .app 和 .dmg
WUKONG_CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  bash mac-standalone/package_distribution.sh
```

边界说明：

- 脚本会自动重新构建独立版 app，并打入自定义图标
- 如果当前机器没有可用签名证书，脚本仍然会正常生成 `.dmg`，但 app 依然属于未被 Apple 识别开发者信任的分发物
- 如果你要让最终用户在默认 Gatekeeper 策略下更顺畅地打开，仍然需要你自己的 `Developer ID Application` 证书

## 4. 使用流程

### 4.1 标准流程

1. 打开悟空 App，并停留在邀请码输入页。
2. 打开抓取页。
3. 点击 `运行脚本并加载图片`。
4. 确认页面展示的是最新邀请码图片。
5. 点击 `手动识别当前图片`。
6. 页面识别成功后，会：
   - 把邀请码写入输入框
   - 尝试复制到剪贴板
   - 如果勾选了 `识别成功后自动填入并提交`，则自动调用本地 bridge，将邀请码填入悟空 App，并尝试点击 `立即体验`

补充说明：

- 当前实现不会在“加载图片”阶段自动 OCR，也不会在识别前自动提交
- 自动填入的触发时机只有两种：识别成功后自动提交，或点击 `填入悟空 App 并立即体验`

### 4.2 手动触发填入

如果识别成功后你不想立刻提交，或自动提交流程失败，可以：

1. 取消勾选 `识别成功后自动填入并提交`
2. 先执行 OCR
3. 确认识别结果无误
4. 点击 `填入悟空 App 并立即体验`

### 4.3 使用 mac app

如果你使用 `.app` 版本，推荐流程如下：

1. 双击 `Wukong Invite Grabber.app`
2. 等待浏览器自动打开抓取页
3. 保持悟空 App 在邀请码输入页
4. 按标准流程执行加载图片、手动识别、自动填入
5. 使用结束后，如需停止后台服务，双击 `Stop Wukong Invite Grabber.app`

## 5. 常见问题

### 5.1 状态区提示“本地 macOS bridge 未启动”

说明页面无法访问本地接口。先在仓库根目录执行：

```bash
python3 tools/wukong_macos_ocr_bridge.py
```

### 5.2 状态区提示“未检测到悟空 App 进程”

说明本地 bridge 没找到悟空 App。当前版本已兼容 `Wukong.app -> DingTalkReal` 的进程映射；如果你仍看到这条报错，优先按下面顺序排查：

- 确认你运行的是最新版本的 `tools/wukong_macos_ocr_bridge.py`
- 停掉旧 bridge 进程后重新启动
- 确认悟空 App 已经打开
- 确认当前显示的是邀请码输入页
- 不要把应用最小化到没有可见窗口

### 5.3 状态区提示“未授予辅助功能权限”

说明 macOS 阻止了 UI 自动化。处理方式：

1. 打开 `系统设置`
2. 进入 `隐私与安全性 > 辅助功能`
3. 给当前运行 bridge 的宿主应用放行
   - 如果 bridge 是从 `Terminal` 启动的，就放行 `Terminal`
   - 如果 bridge 是从 `iTerm` 启动的，就放行 `iTerm`
   - 如果 bridge 是从 `Codex` 或其他宿主中启动的，就放行对应宿主
   - 如果你使用的是独立 app 版本，就放行 `Wukong Invite Grabber.app`
4. 重新启动 bridge 再试

### 5.4 OCR 成功，但没有自动提交

当前机器上，这条链路已经实测通过。当前实现会优先尝试点击按钮文字包含 `立即体验` 的控件；如果点不到，会回退为回车提交。若你后续又遇到失败，通常是以下原因之一：

- 悟空 App 当前页面不是邀请码输入页
- App 的无障碍树没有暴露可点击按钮
- 当前输入焦点不在邀请码输入框附近，或系统权限不足
- 悟空 App 升级后修改了按钮文案或窗口结构

这时可以保留自动 OCR，只用 `复制邀请码`，再人工粘贴验证。

## 6. 已实现行为说明

当前页面行为如下：

- `运行脚本并加载图片` 只负责加载图片，不会自动 OCR
- `手动识别当前图片` 才会开始识别
- OCR 优先尝试本地 macOS Vision；失败后回退到浏览器侧 Tesseract
- 成功识别后，可自动或手动把邀请码填入悟空 App
- 自动填入优先直接写入 App 输入框；若窗口结构不支持直接写值，再回退到键盘输入
- 自动提交优先点击文字包含 `立即体验` 的按钮；若找不到按钮，再回退为回车提交

## 7. 诊断建议

如果需要最小化检查本地 bridge，可执行：

```bash
curl http://127.0.0.1:8788/health
```

返回类似：

```json
{"ok": true, "platform": "Darwin", "mode": "macos-vision"}
```

如果要单独验证自动填入接口是否可达，可执行：

```bash
curl -X POST http://127.0.0.1:8788/fill-app \
  -H 'Content-Type: application/json' \
  --data '{"code":"灵吉定黄风","submit":true}'
```

预期结果：

- 如果悟空 App 已打开、权限已放行、页面在邀请码输入页，则会返回成功 JSON
- 如果悟空 App 未打开、权限缺失或窗口不可操作，则会返回明确错误，而不是静默失败

## 8. 本机验收记录

本机最近一次验收结论如下：

- 验收日期：`2026-03-24`
- 验收环境：`macOS` + 本地 bridge + 当前安装的 `Wukong.app`
- 验收结果：`通过`
- 通过条件：
  - 悟空 App 已打开并停留在邀请码输入页
  - bridge 使用最新代码重启
  - macOS `辅助功能` 权限已授予 bridge 的宿主应用
