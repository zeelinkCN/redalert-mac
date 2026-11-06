# 红警作战中心 · RedAlertMac

[![Release](https://img.shields.io/github/v/release/zeelinkCN/redalert-mac?include_prereleases)](https://github.com/zeelinkCN/redalert-mac/releases)
[![macOS build](https://github.com/zeelinkCN/redalert-mac/actions/workflows/macos.yml/badge.svg)](https://github.com/zeelinkCN/redalert-mac/actions/workflows/macos.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

原生 macOS 红警客户端，启动**原版 Windows 红警程序**。默认提供红色警戒 2、尤里的复仇、共和国之辉的简体中文部署配置，也可管理其他 RA2 / 尤里 MOD。

Native macOS launcher for **Command & Conquer: Red Alert 2**, **Yuri's Revenge** and the classic **共和国之辉** MOD. Built with SwiftUI; runs the original games through Wine, with automatic runtime setup and Simplified Chinese resources.

采用 **SwiftUI 客户端 → Wine WoW64 → 原版 EXE + 原版 MIX 资源**。游戏规则、战斗、战役和存档由原游戏负责；本项目没有重写红警引擎。

## 下载与使用

当前版本：[v0.1.0 预览版](https://github.com/zeelinkCN/redalert-mac/releases/tag/v0.1.0)，支持 **Apple Silicon Mac（M1 及更新芯片），macOS 13+**。

1. 从 [GitHub Releases](https://github.com/zeelinkCN/redalert-mac/releases) 下载 `RedAlertMac-v0.1.0-macos-arm64.dmg`，打开后将「红警作战中心」拖入 Applications，再从启动台打开。
2. 选择默认版本，点击「开始作战」。尚未部署的版本点击「下载并部署」，客户端自动下载、校验、解包、安装中文资源和音乐。
3. Wine、Rosetta、32 位运行能力检测、原版组件注册和独立 Windows 环境均自动处理。
4. 默认无边框全屏，分辨率跟随当前显示器。按 **Ctrl + Tab** 释放鼠标；**Option + Enter** 切换窗口 / 全屏；**Command + Tab** 切换应用。

日常使用不需要终端、Homebrew、Swift 或手动安装 Wine。首次部署需要联网下载运行环境和所选版本资源；默认游戏部署面向已拥有对应游戏的用户。

预览包使用 ad-hoc 签名，尚未经过 Apple Developer ID 签名和公证。macOS 如拦截打开，请按系统提示在「系统设置 → 隐私与安全」允许打开。

默认资源保存在本机独立游戏库，默认分发包提供遭遇战和原有联机入口，**不包含完整战役及过场动画**。联机账号与服务可用性由原服务提供。已有完整版可通过「导入游戏」建立额外档案。

自定义导入选择已安装、已解压的完整目录，不直接选择 ZIP、ISO 或安装器。导入会建立独立副本并保留原目录。部分发行版本仍依赖其原有平台或光盘，客户端不修改其授权逻辑。

| 类型 | 默认启动程序（按优先级） | 基础资源检查 |
| --- | --- | --- |
| 红警 2 | `game.exe`、`ra2.exe`、`Red Alert 2.exe` | `ra2.mix`、`language.mix` |
| 尤里的复仇 | `gamemd.exe`、`yuri.exe`、`ra2md.exe`、`Yuri's Revenge.exe` | 上述文件，以及 `ra2md.mix`、`langmd.mix` |
| 共和国之辉 | `game.exe`、`ra2.exe` | 需要已安装好的完整 MOD 目录 |
| 自定义 MOD | 可选根目录中的 EXE；参数每行一个 | 按 RA2 或尤里基础检查 |

文件名识别不区分大小写。资源检查用于识别安装基础，不能证明战役、音乐与 MOD 文件完整。同一原始目录可以多次导入为不同档案，每次使用独立副本。共和国之辉的分类不会把原版游戏自动变为 MOD。Ares / Phobos / Syringe、CnCNet 或 .NET 启动器的兼容性需要单独实测；不保证所有 MOD 都可运行。

## 功能

- 原生中文游戏库，多个版本和多个同类档案。
- 独立游戏副本、存档、Wine prefix；移除副本使用 macOS 废纸篓。
- Windows EXE 文件头检查、游戏目录识别、复制导入。
- 内置 cnc-ddraw 7.1.0.0，默认 GDI，无边框全屏自动适配显示器；支持手动分辨率及窗口模式。
- 首次显示配置调整前备份，可恢复原 INI / DLL，保留原文件中的中文 ANSI 字节。
- 自动安装经过固定 SHA-256 校验的 Wine 11.21 macOS 构建（含 GStreamer），并自动处理 Rosetta。
- 默认部署包含社区简体汉化包、中文字库、菜单与图标资源、原版音乐；语音以所用语言包内容为准。
- 独立启动日志、启动错误提示、按游戏 prefix 退出进程。
- 全程使用参数数组启动进程，支持中文路径和空格。

Mac 的 Option 键对应游戏里的 Alt。全屏使用当前显示器的逻辑分辨率，保留 Retina 屏幕上可读的操作栏；窗口缩放保持画面比例。新 macOS Wine 构建可能不包含 OpenGL，默认保留 GDI。

## 构建与测试

需要 macOS 13+ 和 Swift 6 工具链 / Command Line Tools，无额外 Swift 包依赖。首次编译会自动获取并校验 cnc-ddraw 和 7-Zip 编译资源；不会下载游戏本体。

```bash
./scripts/build.sh
./scripts/test.sh
./scripts/run.sh
./scripts/package-dmg.sh
```

产物为当前 Mac 架构的 `dist/红警作战中心.app`，经过本地 ad-hoc 签名。源码可为 Intel / Apple Silicon 编译；当前发布的 DMG 与本机运行检查仅覆盖 Apple Silicon，尚未提供 Intel 安装包。

脚本在本机优先使用已安装的稳定 macOS 26.5 SDK：当前预览版 CLT 27.2 缺少 SwiftUI State 宏插件。其他机器默认使用所选 SDK，也可用 `REDALERT_SDK=/path/to/MacOSX.sdk` 覆盖。

```bash
./dist/redalertctl environment
./dist/redalertctl inspect "/path/to/Red Alert 2"
./dist/redalertctl install-wine "/path/to/wine-devel-11.21-osx64.tar.xz"
./dist/redalertctl probe
```

`probe` 创建单独诊断 prefix 并运行 Wine 的 **32 位 cmd.exe**，用于检查 WoW64；通过此检查仍不代表游戏已经实测通过。

## 数据位置

```text
~/Library/Application Support/RedAlertMac/
  library.json       # 档案和设置，原子写入
  Games/<UUID>/      # 游戏副本、原版存档、.redalert-backup/
  Prefixes/<UUID>/   # 每个游戏独立的 Windows 环境
  Runtimes/          # 用户托管的 Wine.app
  Downloads/         # 经过 SHA-256 校验的默认游戏、MOD、汉化和音乐包
  Logs/              # 启动日志
```

开发测试可设置 `REDALERT_DATA_DIR` 指向临时目录。测试不会向真实游戏库添加模拟游戏。

## 当前边界与后续版本

客户端编译、文件导入与配置流程可以在没有游戏资源时验证；**真正进入战役、遭遇战和联机，必须用用户的完整游戏版本在本机验证**。本仓库不会把界面完成或模拟文件测试称为游戏已可玩。

当前没有接入红警 1、红警 3、独立匹配服务器或 MOD 下载市场。后续可为红警 1 接入 [Vanilla Conquer](https://github.com/TheAssemblyArmada/Vanilla-Conquer) 的原引擎移植，为红警 3 建立独立图形和启动配置。

参考项目与许可证见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)，技术选择见 [docs/architecture.md](docs/architecture.md)。

## 开源许可证

本项目原创客户端代码采用 [MIT License](LICENSE)，可使用、修改和再分发，并保留许可证及版权声明。第三方组件与游戏资源沿用各自许可证，不受本项目 MIT 许可证覆盖；详见 [第三方声明](THIRD_PARTY_NOTICES.md)。发行包附带所用 7-Zip 的完整对应源码。

欢迎通过 [Issues](https://github.com/zeelinkCN/redalert-mac/issues) 反馈兼容性问题。请附 Mac 芯片、macOS 版本、游戏版本与启动日志。
