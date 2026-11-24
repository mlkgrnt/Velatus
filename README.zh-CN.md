# 隐格 Velatus

> **简体中文** · [繁體中文](README.zh-TW.md) · [English](README.md) · [Español](README.es.md) · [Français](README.fr.md)

[![CI](https://github.com/mlkgrnt/Velatus/actions/workflows/ci.yml/badge.svg)](https://github.com/mlkgrnt/Velatus/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**隐格**（拉丁语 Velatus，意为「被覆盖的」）是一个给截图和照片打码的小工具，
全程只在这台设备上完成，图片不会上传。

![首页](docs/screenshots/home_light.png)

## 为什么做它

很多打码工具一画下去就定死了。隐格把每一处遮挡都当成可以改的对象：点一下
选中，就能移动、缩放、换样式或者删掉，导出之前随时可以反悔。

- **两种手势**：用笔刷涂抹，或者拖一个框。框的四角可以用圆角条磨圆，直角
  只是把圆角调到零，所以不会有两个长得几乎一样的工具。
- **三种效果**：马赛克、高斯模糊、色块。色块有 10 个预设，也可以自己调
  颜色。模糊强度会随图片尺寸缩放，导出和预览看起来一样。
- **选择真的好用**：点一下加选，再点一下取消。多选时拖动只移动你碰到的那个
  框，角点拉过对角点可以直接翻到另一个象限；改强度、样式、圆角、颜色时，
  整组一起生效。
- **撤销、重做、对比**：60 步历史；点一下眼睛固定看原图，再点一下回到打码后，
  按住则临时预览另一侧。双指、滚轮、双击都能缩放，桌面端还能中键拖动画布。
- **记得上一次**：打开新图片时，上次用的工具和参数还在；导出用的格式、
  质量、保存位置也一样。

![编辑器](docs/screenshots/editor_mobile.png)

## 扫描先给框，你来挑

扫描会找出三类东西，只画**虚线候选框**，不会自己盖上去。点选要盖住的框，
按「确认」才生效；确认之后就是普通的遮挡，仍然可以随便改。再扫一次会替换
上一次的候选，不会一层层叠上去。

| | 做法 |
| --- | --- |
| 文字 | ML Kit 中英文离线文字识别，模型打包在应用里（**仅 Android**） |
| 聊天头像 | 纯 Dart 图像处理：自适应前景归一化 + 积分图、投影判断方形/圆角/圆形、单频 DFT 找列的重复节奏，再拿一个高置信度头像当模板回扫左右对称页边，连只出现一次的头像也能找回；最后按列统一左右边界与边长，同一列头像框严格等大 |
| 二维码 | `zxing2`，约 200 KB 的纯 Dart 代码，框住的是二维码本体 |

两句实话：它识别的是「文字」，不是「敏感文字」，哪些该遮由你决定；头像
是启发式，遇到特别的头像可能会漏。文字以外的两种检测在 Android 和
Windows 上都能用。

![扫描候选框](docs/screenshots/editor_scan.png)

## 导出

- 按原图分辨率导出，遮挡按原始像素重新绘制，不是把预览小图放大。
- JPEG（质量默认 **100**）或 PNG。**EXIF 一定会被清除**，定位、机型、时间
  不会跟着图片一起发出去。
- Android 可以存到相册或 Download 目录；桌面端用系统保存对话框，下次会直接
  回到上次用的文件夹。也可以直接调系统分享。
- 格式、质量、保存位置都会记住。

## 隐私

所有处理都在本机完成。图片不会上传，也不做任何统计。应用唯一会联网的地方
是检查和下载更新：优先访问 GitHub，连不上时会换镜像；不想用也没关系，
更新窗口里同样给了打开发布页的普通链接。

## 语言和外观

简体中文、繁體中文、English、Español、Français；浅色、深色，或者跟系统
一样。只有中文界面会显示「隐格」，其它语言一律叫 Velatus。

![设置](docs/screenshots/settings_light.png)

## 下载

到 [Releases](https://github.com/mlkgrnt/Velatus/releases) 取最新版。

| 文件 | 说明 |
| --- | --- |
| `velatus-<版本>-android-arm64-v8a.apk` | 2016 年之后的手机基本都是这个，先试它 |
| `velatus-<版本>-android-armeabi-v7a.apk` | 老一点儿的 32 位设备 |
| `velatus-<版本>-windows.exe` | **单个文件**，不用安装，见下面 |
| `velatus-windows.zip` | 同样的 Windows 版本，普通文件夹形式 |

那个 Windows exe 是便携启动器，不是安装程序：第一次运行会把 Flutter 运行库
展开到 `%LOCALAPPDATA%\Velatus\<版本>`，再从那里启动；之后再打开就是直接
启动。不需要管理员权限，也不会在 exe 旁边留下一堆文件。因为没有签名，
Windows SmartScreen 首次运行可能会提醒一下；不放心的话可以下载 zip 自己
解压。

所有 APK 都用同一个公开的 debug 签名，新版可以直接覆盖安装。从 0.3.0 起，
也可以在「设置 → 检查更新」里让应用自己更新。

## 从源码构建

Flutter **3.50.1** / Dart **3.14.0**（或同一稳定世代的更新版本）。打 Android
包需要 Android SDK，打 Windows 包需要 Visual Studio 的 C++ 桌面工具链。

```sh
flutter pub get
flutter gen-l10n           # 改过 lib/l10n/*.arb 之后才需要
flutter analyze
flutter test
flutter build apk --release --split-per-abi
flutter build windows --release
```

单文件 exe 由 CI 用
[`tool/windows_portable/package.ps1`](tool/windows_portable/package.ps1) 生成：
把整个 release 目录塞进一个很小的 C# 启动器，编译器用的是 Windows 自带的
.NET Framework 编译器。本地也可以自己跑：

```powershell
./tool/windows_portable/package.ps1 `
  -ReleaseDir build/windows/x64/runner/Release `
  -Version 0.4.1 -Out velatus-0.4.1-windows.exe
```

`docs/screenshots/` 里的截图用
`flutter test --update-goldens tool/screenshots_test.dart` 重新生成。

## 许可证

MIT，见 [LICENSE](LICENSE)。
