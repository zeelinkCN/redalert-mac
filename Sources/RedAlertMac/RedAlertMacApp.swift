import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard model?.runningID != nil else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "游戏仍在运行"
        alert.informativeText = "请先在游戏内保存并退出，再关闭作战中心。"
        alert.addButton(withTitle: "继续游戏")
        alert.runModal()
        return .terminateCancel
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main struct RedAlertMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model = AppModel()
    var body: some Scene {
        WindowGroup("红警作战中心") {
            ContentView().environmentObject(model)
                .frame(minWidth: 1060, minHeight: 720)
                .preferredColorScheme(.dark)
                .onAppear { delegate.model = model }
        }
        .defaultSize(width: 1240, height: 820)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("导入游戏…") { model.chooseImport() }.keyboardShortcut("o")
            }
            CommandMenu("游戏") {
                Button("启动所选游戏") { model.launch() }.keyboardShortcut(.return)
                    .disabled(model.selectedProfile == nil || model.runningID != nil)
                Button("查看启动日志") { model.openLog() }.keyboardShortcut("l")
                Button("重新检测运行环境") { model.refreshEnvironment() }
            }
        }
    }
}
