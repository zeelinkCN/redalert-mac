import SwiftUI
import AppKit
import RedAlertCore

struct EnvironmentView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 23) {
            HStack {
                VStack(alignment: .leading, spacing: 9) {
                    Text("SYSTEM READINESS").font(.system(size: 9, design: .monospaced)).tracking(2).foregroundStyle(Theme.red)
                    Text("兼容组件，自动就绪。").font(.system(size: 26, weight: .bold))
                    Text("下载、安装、验证和版本隔离均由客户端自动完成。").font(.system(size: 12)).foregroundStyle(Theme.secondary)
                }
                Spacer()
                ActionButton(title: "重试自动准备", icon: "arrow.clockwise", primary: false) { model.prepareAutomatically() }
            }
            VStack(spacing: 0) {
                row("desktopcomputer", title: RuntimeManager.isAppleSilicon ? "Apple Silicon Mac" : "Intel Mac", detail: "客户端原生运行 · macOS 13 或更新版本", ready: true)
                Divider().overlay(Theme.line)
                row("arrow.triangle.2.circlepath", title: "Rosetta 2", detail: RuntimeManager.isAppleSilicon ? "客户端自动安装的 Apple Intel 兼容组件，无需手动操作。" : "Intel Mac 无需此组件。", ready: model.rosettaReady)
                Divider().overlay(Theme.line)
                row("cpu", title: "Wine 运行层", detail: model.runtime?.executable.path ?? "正在自动检测并安装，无需手动配置。", ready: model.runtime != nil)
                Divider().overlay(Theme.line)
                row("display", title: "cnc-ddraw 7.1.0.0", detail: "已内置开源显示兼容补丁 · 默认 GDI 渲染 · 支持窗口与分辨率设置", ready: true)
            }.background(Theme.panel, in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))
            DisclosureGroup("高级选项（通常无需操作）") { HStack(spacing: 12) {
                ActionButton(title: "选择已有 Wine", icon: "folder", primary: false) { model.chooseWine() }
                ActionButton(title: "从安装包安装", icon: "archivebox", primary: false) { chooseArchive() }.disabled(model.runningID != nil)
                Spacer()
                Button("打开运行环境目录") { NSWorkspace.shared.open(model.paths.runtimes) }.font(.system(size: 11)).foregroundStyle(Theme.secondary).buttonStyle(.plain)
            }.padding(.top, 12) }.font(.system(size: 11)).foregroundStyle(Theme.secondary)
            VStack(alignment: .leading, spacing: 13) {
                Label("关于原版兼容性", systemImage: "info.circle").font(.system(size: 13, weight: .semibold))
                Text("支持导入红警 2、尤里的复仇与已安装的共和国之辉。客户端运行你提供的原版 EXE，不包含游戏本体。需要 Ares、Phobos、Syringe 或专用联机客户端的 MOD，可在版本设置中选择启动程序与参数；具体兼容性仍需实际游戏验证。")
                    .font(.system(size: 12)).foregroundStyle(Theme.secondary).lineSpacing(6)
                Text("Wine 11.21 为固定版本，安装包经 SHA-256 校验，包含 GStreamer。首次创建 Windows 环境可能需要数分钟。")
                    .font(.system(size: 11)).foregroundStyle(Theme.secondary).lineSpacing(5)
                HStack(spacing: 22) {
                    Link("Wine 构建来源 ↗", destination: URL(string: "https://github.com/Gcenx/macOS_Wine_builds/releases/tag/11.21")!)
                    Link("cnc-ddraw ↗", destination: URL(string: "https://github.com/FunkyFr3sh/cnc-ddraw")!)
                }.font(.system(size: 11)).tint(Theme.gold)
            }.padding(23).background(Theme.panel, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func row(_ icon: String, title: String, detail: String, ready: Bool) -> some View {
        row(icon, title: title, detail: detail, ready: ready) { EmptyView() }
    }
    private func row<Actions: View>(_ icon: String, title: String, detail: String, ready: Bool, @ViewBuilder actions: () -> Actions) -> some View {
        HStack(spacing: 17) {
            Image(systemName: icon).font(.system(size: 21, weight: .light)).foregroundStyle(Theme.secondary).frame(width: 30)
            VStack(alignment: .leading, spacing: 7) {
                HStack { Text(title).font(.system(size: 14, weight: .semibold)); Tag(text: ready ? "已就绪" : "待准备", color: ready ? Theme.green : Theme.gold) }
                Text(detail).font(.system(size: 11)).foregroundStyle(Theme.secondary).lineLimit(3).textSelection(.enabled)
            }
            Spacer(minLength: 10)
            actions()
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
    }
    private func chooseArchive() {
        let panel = NSOpenPanel(); panel.title = "选择官方 Wine 11.21 tar.xz 安装包"
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        model.installRuntime(archive: url)
    }
}

struct GuideView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 9) {
                Text("FIELD MANUAL").font(.system(size: 9, design: .monospaced)).tracking(2).foregroundStyle(Theme.red)
                Text("重返战场，只需三步。").font(.system(size: 26, weight: .bold))
            }
            instruction("01", "选择你的战场", "在游戏库选择红警 2、尤里的复仇或共和国之辉，点击「开始作战」。尚未部署的版本点击「下载并部署」，文件、简体汉化、中文字库和音乐都会自动准备。默认包以遭遇战和原有联机入口为主，完整战役与过场需要追加完整版资源。")
            instruction("02", "自动准备兼容组件", "客户端会自动下载和安装 Wine、Apple Silicon 兼容组件，并验证 32 位程序运行能力。独立 Windows 环境和显示补丁也会自动配置，无需手动准备。")
            instruction("03", "全屏开战，随时切回桌面", "默认无边框全屏，启动时按当前显示器自动适配分辨率，Retina 屏幕上的操作栏保持可读。Ctrl + Tab 释放鼠标；Option + Enter 切换窗口和全屏；Command + Tab 切换应用。也可以在版本设置中关闭自动分辨率并指定宽高。")
            instruction("+", "多个版本与 MOD", "同一个游戏目录可以分别以红警 2、尤里等类型导入；每次导入都会建立独立副本。为 MOD 选择「自定义 MOD」，可自行设置 EXE、逐行填写参数，或关闭 cnc-ddraw 使用 MOD 自带的显示补丁。联机需要该版本原有的联机环境；本客户端不提供独立匹配服务器。")
            instruction("?", "黑屏、闪退或要求光盘", "先查看启动日志，再尝试窗口模式、GDI 渲染和 1024 × 768 分辨率。游戏目录缺失、原版光盘检查、EA / Steam 授权检查仍取决于你所使用的发行版本。客户端不修改原版程序，也不绕过其授权。CnCNet 启动器可能需要额外 .NET 运行库。")
            HStack(spacing: 12) {
                ActionButton(title: "导入游戏", icon: "plus") { model.chooseImport() }
                ActionButton(title: "打开游戏库目录", icon: "folder", primary: false) { NSWorkspace.shared.open(model.paths.root) }
            }
            Text("当前版本聚焦红警 2 系列。红警 1 可后续接入 Vanilla Conquer 原引擎移植；红警 3 需要独立的 3D 图形与兼容配置，尚未集成。")
                .font(.system(size: 11)).foregroundStyle(Theme.secondary).lineSpacing(5)
        }
    }
    private func instruction(_ number: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 20) {
            Text(number).font(.system(size: 17, weight: .light, design: .monospaced)).foregroundStyle(Theme.red).frame(width: 29)
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.system(size: 15, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(Theme.secondary).lineSpacing(6).fixedSize(horizontal: false, vertical: true)
            }
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading).background(Theme.panel, in: RoundedRectangle(cornerRadius: 10))
    }
}

struct LogView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("启动日志").font(.system(size: 20, weight: .bold)); Spacer()
                Button("刷新") { model.refreshLog() }
                Button("在访达中显示") { if let url = model.logURL { NSWorkspace.shared.activateFileViewerSelecting([url]) } }.disabled(model.logURL == nil)
                Button("关闭") { model.showLog = false }.keyboardShortcut(.cancelAction)
            }
            Text(model.logURL?.lastPathComponent ?? "尚未启动游戏").font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.secondary)
            ScrollView([.horizontal, .vertical]) {
                Text(model.logText).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading).padding(16)
            }.background(Theme.background, in: RoundedRectangle(cornerRadius: 8))
        }.padding(24).frame(width: 840, height: 550).background(Theme.panel)
    }
}
