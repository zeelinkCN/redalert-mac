# 技术路线与验证范围

## 为什么运行原版程序

用户要求保留原版红警并支持多个版本。本项目只实现 macOS 的版本管理与运行适配，原游戏的 EXE 和 MIX 文件保持原样。显示 DLL / INI 仅修改独立导入副本，首次修改前记录哪些文件原本存在并备份。

[RA2Web 的 README](https://github.com/OpenRA2/RA2Web#readme) 自述来源于 Chrono Divide 客户端反编译，不能据其仓库的开源标签推定底层客户端获得了开源授权。本项目未复制这部分代码。

[Chrono Divide MOD SDK](https://github.com/chronodivide/mod-sdk) 描述其引擎对原版 RA2 v1.006 MOD 的兼容目标；它也不能代替原版尤里、全部 MOD 与战役程序。因此使用网页封装无法满足这里的原版多版本优先目标。

## 启动路径

1. 选择、扫描游戏目录，匹配不区分大小写的 EXE / MIX 文件名。
2. 检查 Windows PE 文件头；复制完整目录到新 UUID；原子保存游戏库。
3. 检查 Wine 与 Rosetta；默认不设置 `WINEARCH=win32`，使用现代 Wine WoW64。
4. 根据用户选择为导入副本准备 cnc-ddraw。保留不相关配置和中文字节，备份原显示文件。
5. 首次通过 Wine 创建独立 prefix；写入 32 位 Westwood `InstallPath` 注册表项。
6. 以游戏目录为工作目录，使用参数数组启动原 EXE；`WINEDLLOVERRIDES=ddraw=n,b`。
7. 等待启动程序及其 prefix 中的子进程退出，记录日志与会话时间。退出只针对该 prefix。

RA2 优先 `game.exe`，尤里优先 `gamemd.exe`，避免只启动原安装器的菜单。特定发行平台的授权与光盘检查仍由原程序负责。

## 复用的适配层

[cnc-ddraw 官方说明](https://github.com/FunkyFr3sh/cnc-ddraw/tree/v7.1.0.0) 将 RA2、尤里列为支持游戏，并要求 Wine 覆盖 ddraw。游戏保持原显示路径，由 cnc-ddraw 决定实际窗口模式。

[Gcenx Wine 11.21 构建](https://github.com/Gcenx/macOS_Wine_builds/releases/tag/11.21) 提供可运行 32 / 64 位 Windows 二进制的 macOS Wine，并捆绑 GStreamer。固定此版本和 GitHub 资产 SHA-256，使用原包而不从不固定的 latest URL 获取。Apple Silicon 上的该 Intel 构建需要 Rosetta。

## 验证范围

自动测试覆盖导入、大小写识别、尤里资源区分、包装目录扫描、损坏 EXE 拒绝、独立副本、游戏库持久化、非 ASCII INI 保留、显示设置恢复、符号链接拒绝和参数传递。这些测试使用临时结构文件，不包含原游戏。

实际游戏验收需另行记录：发行版本、EXE 与关键资源校验和、Wine 版本、Mac 与系统版本、主菜单、战役、遭遇战、存档读写、音效与鼠标操作。共和国之辉须使用其完整目录单独验收；MOD 不通过文件名自动推断为已安装。
