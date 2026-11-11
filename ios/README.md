# FMO-X for iOS

FMO-X 的 iOS 版：一个最小的 WKWebView 壳，加载与安卓版 1.6.6 完全相同的
控制页面（`ios/App/Resources/index.html`，取自安卓版安装包解包后的
`assets/index.html`，含 7 种动画、呼号牌底部 45px、BG5DRT 致谢）。

## 关键信息

- 名字：FMO-X，包名 `com.x.fmocontroller`，版本 1.6.6（build 3），与安卓版一致。
- 最低支持 iOS 14.0（巨魔本身也只支持 iOS 14.0 起，再低没有意义）。
- 未签名：专供巨魔（TrollStore）安装，不走 App Store。
- 页面只用标准网页技术：3 条 WebSocket（`/ws`、`/audio`、`/events`）+
  Web Audio，没有任何原生桥接，所以一个 WKWebView 就够了。
- `Info.plist` 里开了 `NSAllowsArbitraryLoads`，否则连不上内网明文 `ws://`；
  开了音频后台模式，锁屏也能继续听。

## 编译

推送到 `main` 分支（改动 `ios/**` 或工作流文件）会自动触发
`.github/workflows/ios-ipa.yml`，在 GitHub 的苹果电脑上编译，
产出未签名的 `FMO-X-1.6.6-ios-unsigned.ipa`，并挂到 `ios-1.6.6` 这个
release 上（已存在就覆盖同名附件）。

图标：`AppIcon-1024.png.b64` 是安卓版启动图标的 base64 文本版
（推送工具不接受二进制文件），工作流里解码后用 `sips` 生成各尺寸。
