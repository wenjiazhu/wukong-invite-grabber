# Wukong Invite Grabber

优先使用 `.app`。终端方式只作为备用。

## 推荐用法：直接打开 app

下载：

- Release 页面：`https://github.com/wenjiazhu/wukong-invite-grabber/releases/tag/v1.0.0`
- `.dmg`：`https://github.com/wenjiazhu/wukong-invite-grabber/releases/download/v1.0.0/wukong-invite-grabber-macOS-1.0.0.dmg`
- `.app.zip`：`https://github.com/wenjiazhu/wukong-invite-grabber/releases/download/v1.0.0/wukong-invite-grabber-macOS-1.0.0.app.zip`

1. 打开 `Wukong Invite Grabber.app`
2. 保持 `Wukong.app` 在邀请码输入页
3. 在抓取页点击 `运行脚本并加载图片`
4. 确认页面展示的是最新邀请码图片
5. 点击 `手动识别当前图片`
6. 识别成功后：
   - 需要手动处理时，点 `复制邀请码`
   - 需要自动写回悟空时，点 `填入悟空 App 并立即体验`

如果是第一次打开 `.app`，需要确认两件事：

- 允许 app 启动
- 在这里给 app 放行权限：

```text
系统设置 > 隐私与安全性 > 辅助功能
系统设置 > 隐私与安全性 > 自动化
```

## app 无法打开时

如果 macOS 因证书或开发者未验证而拦截：

1. 在 Finder 里找到 `Wukong Invite Grabber.app`
2. 右键 app，选择 `打开`
3. 在系统弹窗里再次点 `打开`

如果右键打开后仍被拦截，到这里手动放行一次：

```text
系统设置 > 隐私与安全性
```

在页面底部找到被拦截的 app，点 `仍要打开`，然后再重新启动。

## 终端备用方案

适用环境：

- `macOS`
- `Python 3`
- `Xcode Command Line Tools`

如果没有安装命令行工具，先执行：

```bash
xcode-select --install
```

在仓库根目录打开两个终端窗口。

终端 1：

```bash
python3 tools/wukong_macos_ocr_bridge.py
```

终端 2：

```bash
python3 -m http.server 4173
```

浏览器打开：

```text
http://127.0.0.1:4173/wukong-invite-grabber.html
```

## 常见问题

### 1. 页面提示本地 bridge 未启动

如果你走的是终端方案，重新执行：

```bash
python3 tools/wukong_macos_ocr_bridge.py
```

### 2. 页面提示未检测到悟空 App

确认：

- `Wukong.app` 已打开
- 当前页面就是邀请码输入页

### 3. 页面提示权限不足

到这里检查并放行当前实际运行的宿主：

```text
系统设置 > 隐私与安全性 > 辅助功能
系统设置 > 隐私与安全性 > 自动化
```

如果列表里已经是开启状态但仍失败，先删除这一项，再重新添加并重启对应的 `.app` 或终端。

### 4. 快速自检

```bash
curl http://127.0.0.1:8788/health
```

如果返回 `ok: true`，说明本地 bridge 已经起来。
