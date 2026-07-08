# MuseHub

[English](README.md)

MuseHub 是一个 Flutter 音乐客户端和自托管音乐编排服务，产品方向参考
[AlgerMusicPlayer](https://github.com/algerkong/AlgerMusicPlayer)。

当前 `v0.1.1` 版本包含 Flutter App、Node.js/SQLite 后端、账号登录、收藏同步、
本地音乐源、网易云兼容搜索/播放，以及可选的 Alger/unblock 备用解析。

## 下载

最新版本：

[MuseHub v0.1.1](https://github.com/MaxZhuangYan/MuseHub/releases/tag/v0.1.1)

发布包：

- Android：`MuseHub-v0.1.1-android-arm64-release.apk`
- macOS：`MuseHub-v0.1.1-macos-arm64.zip`
- Web：`MuseHub-v0.1.1-web.zip`
- iOS：`MuseHub-v0.1.1-ios-unsigned.zip`

说明：

- Android APK 是 release 构建，但还没有配置正式生产 keystore；适合直接安装测试，不适合上架。
- iOS 包是未签名的 `Runner.app` 压缩包。它表示 iOS release 构建能通过，但不能像 APK 一样直接安装。
  需要用 Xcode 配置 Apple Team、Bundle ID 和 Provisioning Profile 后签名，或重新 Archive 走
  TestFlight、Ad Hoc、App Store 等分发方式。
- Windows 包需要在 Windows 机器或 CI runner 上构建。

如果只是自己用 iPhone 测试，打开 `ios/Runner.xcworkspace`，在 Xcode 里选择自己的
Apple 开发团队，连接 iPhone 后运行/签名。

## 服务器配置

App 可以连接 MuseHub Server 来同步账号和收藏。在 App 设置里填你自己的服务器地址：

```txt
MuseHub Server: https://your-musehub-server.example
Alger Resolver: 如果你没有自己运行解析服务，就留空
```

手机或模拟器里不要把 `127.0.0.1` 当成远程服务器地址；手机上的 `127.0.0.1`
指的是手机自己。请填写服务器 IP、域名，或者同一局域网里的主机地址。

## 功能

- 首页发现、搜索、资料库、设置、迷你播放器、全屏播放器
- 基于 `just_audio` 的队列播放
- 网易云直连/兼容 API 支持
- 可选 Alger/unblock 备用解析
- MuseHub Server 账号注册和登录
- 同账号跨设备收藏同步
- 后端 Track 身份、Source Binding、歌单、收藏、播放状态、历史 API
- 后端本地音乐目录源
- 后端流媒体代理，支持 HTTP Range 请求

## 项目结构

```txt
lib/
  core/                 Flutter 状态、API 客户端、模型、主题、通用组件
  features/             首页、搜索、资料库、设置、播放器页面
  player/               队列和播放控制器
  main.dart             Flutter App 入口

musehub-server/
  src/                  Hono + SQLite 后端
  scripts/              Smoke test 和示例数据脚本

tools/alger_resolver/   可选 unblock resolver 包装服务
release/v0.1.1/         已打包的发布产物
```

## 运行 Flutter App

安装 Flutter 3.44 或更新版本：

```sh
flutter pub get
flutter run
```

常用本地目标：

```sh
flutter run -d macos
flutter run -d chrome
flutter run -d android
```

## 运行 MuseHub Server

```sh
cd musehub-server
npm install
npm run dev
```

默认配置：

- HTTP：`http://127.0.0.1:30490`
- SQLite：`./data/musehub.sqlite`
- 本地音乐目录：`/music`

使用本地示例音乐：

```sh
cd musehub-server
npm run sample:local
MUSIC_DIR=./music npm run dev
```

更多后端说明见 [musehub-server/README.md](musehub-server/README.md)。

## 可选 Alger Resolver

当主音源无法返回可播放 URL 时，MuseHub 可以调用 Alger 风格的 unblock resolver。

```sh
cd tools/alger_resolver
npm install
npm start
```

默认 resolver 地址：

```txt
http://127.0.0.1:30489
```

不同平台在 App 里填写：

```txt
macOS 桌面目标：       http://127.0.0.1:30489
Android 模拟器：       http://10.0.2.2:30489
同一 Wi-Fi 的真机：    http://YOUR_MAC_LAN_IP:30489
```

不需要备用解析时留空。

## 构建

```sh
flutter analyze
flutter test

flutter build apk --release
flutter build macos --release
flutter build web --release
flutter build ios --release --no-codesign
```

后端验证：

```sh
cd musehub-server
npm run typecheck
npm run build
npm run smoke
```

## 发布说明

`v0.1.1` 是播放稳定性版本，重点改善海外网络环境下的播放链路，增强短试听片段和截断音频源过滤，
播放时补齐 CDN 兼容请求头，并优化全屏播放器歌词跟踪体验。

这个版本可以用于本地测试和基于 server 的收藏同步。正式分发还需要：

- Android 正式签名配置
- iOS Apple 签名和 provisioning
- Windows 环境打包
- Flutter 客户端继续补全歌单/历史同步
