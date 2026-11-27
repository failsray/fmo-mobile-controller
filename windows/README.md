# FMO-X Windows 1.6.6

FMO-X 的 Windows 桌面版：Electron 22 壳 + 与 iOS、安卓版同一份单文件网页（app/index.html）。

- 版本 1.6.6（与安卓、iOS 同升同版，版本号永久冻结，除非 RAY 说要更新）
- 包名 com.x.fmocontroller，未签名
- 最低支持 Windows 7 SP1（Electron 22 是最后一个支持 Win7 的版本）

## 页面与图标来源

构建时从本仓库的 iOS 工程复制，不在本目录另存一份：

- 页面：`ios/App/Resources/index.html` → `windows/app/index.html`
- 图标：`ios/App/Resources/AppIcon-1024.png.b64`（蓝色对讲机原版）→ 解码成 `windows/app/icon.png`，再由 `scripts/make-ico.py`（Pillow）转成 `app/icon.ico`

所以页面一改，桌面版重新跑一次 workflow 就跟着最新版走。

## 构建

GitHub Actions（`.github/workflows/windows-app.yml`）：Windows runner 上 npm install、electron-builder 打 NSIS 一键安装包，产出 `FMO-X-1.6.6-windows-setup.exe`，同时发到 release `windows-1.6.6`。

## 安装

双击安装包一路下一步即可。未签名，Windows 可能会弹 SmartScreen：点“更多信息” → “仍要运行”。

装好打开即用：默认连内网 192.168.110.198；外网使用时在页面设置里填外网地址。
