# FMO-X macOS 1.6.6

FMO-X 的 macOS 桌面版：WKWebView 壳 + 与 iOS、安卓版同一份单文件网页（index.html）。

- 版本 1.6.6（与安卓、iOS 同升同版，版本号永久冻结，除非 RAY 说要更新）
- 包名 com.x.fmocontroller，未签名
- 最低支持 macOS 10.15（Catalina），Intel 架构（Apple Silicon 上走 Rosetta 2 也能跑）

## 页面与图标来源

构建时从本仓库的 iOS 工程复制，不在本目录另存一份：

- 页面：`ios/App/Resources/index.html` → `macos/App/Resources/index.html`
- 图标：`ios/App/Resources/AppIcon-1024.png.b64`（蓝色对讲机原版）→ 解码后用 sips 生成各尺寸进 `AppIcon.appiconset`

所以页面一改，桌面版重新跑一次 workflow 就跟着最新版走。

## 构建

GitHub Actions（`.github/workflows/macos-app.yml`）：macOS runner 上 xcodegen 生成工程、xcodebuild 编译（不签名），产出 `FMO-X-1.6.6-macos-unsigned.zip`（内含 FMO-X.app），同时发到 release `macos-1.6.6`。

## 安装

解压后把 FMO-X.app 拖进“应用程序”。未签名，首次打开请在 Finder 里右键 FMO-X.app → 打开，点“打开”确认一次，之后双击就能开。

打开即用：默认连内网 192.168.110.198；外网使用时在页面设置里填外网地址。
