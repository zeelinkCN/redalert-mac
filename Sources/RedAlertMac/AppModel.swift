import SwiftUI
import AppKit
import RedAlertCore

enum Page: String, CaseIterable {
    case library = "游戏库", environment = "运行环境", guide = "使用指南"
    var icon: String {
        switch self { case .library: return "square.grid.2x2"; case .environment: return "cpu"; case .guide: return "book.closed" }
    }
}

@MainActor final class AppModel: ObservableObject {
    let paths: AppPaths
    let runner = GameRunner()
    @Published var state = LibraryState()
    @Published var page: Page = .library
    @Published var selectedKind: GameKind = .redAlert2
    @Published var selectedID: UUID?
    @Published var runtimes: [WineRuntime] = []
    @Published var rosettaReady = false
    @Published var busy: String?
    @Published var runningID: UUID?
    @Published var runMessage = ""
    @Published var error: String?
    @Published var notice: String?
    @Published var inspections: [GameInspection] = []
    @Published var showImport = false
    @Published var editingProfile: GameProfile?
    @Published var logURL: URL?
    @Published var logText = ""
    @Published var showLog = false
    @Published var loadFailed = false
    private var automaticSetupStarted = false
    var selectedProfile: GameProfile? { state.profiles.first { $0.id == selectedID } ?? state.profiles.first { $0.kind == selectedKind } }
    var runtime: WineRuntime? { runtimes.first }
    var compatibility: URL { Bundle.module.url(forResource: "Compatibility", withExtension: nil)! }
    var extractor: URL {
        Bundle.module.url(forResource: "7zz", withExtension: nil, subdirectory: "Tools")
            ?? Bundle.module.resourceURL!.appendingPathComponent("Tools/7zz")
    }

    init() {
        let customRoot = ProcessInfo.processInfo.environment["REDALERT_DATA_DIR"].map { URL(fileURLWithPath: $0) }
        paths = AppPaths(root: customRoot)
        do { state = try LibraryStore(paths: paths).load() }
        catch { self.error = "读取游戏库失败：\(error.localizedDescription)"; loadFailed = true }
        if let raw = UserDefaults.standard.string(forKey: "selectedGameKind"), let kind = GameKind(rawValue: raw) {
            selectedKind = kind; selectedID = state.profiles.first { $0.kind == kind }?.id
        }
        refreshEnvironment()
    }

    func refreshEnvironment() {
        runtimes = RuntimeManager.detect(paths: paths, customPath: state.customWinePath)
        Task {
            rosettaReady = await Task.detached { RuntimeManager.rosettaAvailable }.value
        }
    }

    func prepareAutomatically(thenLaunch: Bool = false) {
        guard busy == nil else { return }
        automaticSetupStarted = true
        busy = "正在自动准备游戏兼容环境…"
        let paths = paths, customPath = state.customWinePath
        Task {
            do {
                _ = try await RuntimeManager.ensureReady(paths: paths, customPath: customPath) { message in
                    Task { @MainActor in self.busy = message }
                }
                busy = nil; rosettaReady = true
                runtimes = RuntimeManager.detect(paths: paths, customPath: customPath)
                if thenLaunch { launch() }
            } catch { busy = nil; self.error = error.localizedDescription }
        }
    }

    func prepareOnFirstAppearance() {
        if !automaticSetupStarted { prepareAutomatically() }
    }

    func deployDefault(_ kind: GameKind) {
        guard kind != .custom else { chooseImport(); return }
        guard busy == nil, runningID == nil, !loadFailed else { return }
        guard FileManager.default.isExecutableFile(atPath: extractor.path) else { error = "客户端解包组件缺失，请重新安装客户端。"; return }
        busy = "正在自动部署\(kind.title)…"
        let paths = paths, extractor = extractor
        let modFiles = paths.root.appendingPathComponent("ModPackages/Republic")
        Task {
            do {
                _ = try await RuntimeManager.ensureReady(paths: paths, customPath: state.customWinePath) { message in
                    Task { @MainActor in self.busy = message }
                }
                let profile = try await DefaultGameInstaller.install(kind: kind, paths: paths, extractor: extractor,
                    modFiles: FileManager.default.fileExists(atPath: modFiles.path) ? modFiles : nil) { message in
                    Task { @MainActor in self.busy = message }
                }
                var next = state; next.profiles.append(profile)
                do { try persist(next) }
                catch { try? FileManager.default.removeItem(at: paths.game(profile.id)); throw error }
                select(kind); selectedID = profile.id
                notice = "\(kind.title)简体中文版已就绪。"
            } catch { self.error = error.localizedDescription }
            busy = nil; refreshEnvironment()
        }
    }

    func select(_ kind: GameKind) {
        selectedKind = kind; selectedID = state.profiles.first { $0.kind == kind }?.id
        UserDefaults.standard.set(kind.rawValue, forKey: "selectedGameKind")
        page = .library
    }

    func persist(_ next: LibraryState) throws {
        guard !loadFailed else { throw RedAlertError.message("游戏库读取失败，已暂停写入以保留原数据。请先检查 library.json。") }
        try LibraryStore(paths: paths).save(next)
        state = next
    }

    func chooseImport() {
        guard busy == nil, !loadFailed else { return }
        let panel = NSOpenPanel()
        panel.title = "选择完整的红警游戏文件夹"
        panel.message = "选择含有 EXE 和 MIX 文件的已安装目录。客户端会复制游戏文件，保留原目录。"
        panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.prompt = "识别游戏"
        guard panel.runModal() == .OK, let directory = panel.url else { return }
        inspectDirectory(directory)
    }

    func inspectDirectory(_ directory: URL) {
        guard busy == nil else { return }
        busy = "正在识别游戏文件…"
        Task {
            do {
                let matches = try await Task.detached { try GameImporter.discover(in: directory) }.value
                busy = nil
                guard !matches.isEmpty else {
                    error = "未找到红警 2 游戏目录。请选择解压后含 ra2.mix、language.mix 和游戏 EXE 的文件夹；客户端不直接导入 ZIP、ISO 或安装器。"
                    return
                }
                inspections = matches; showImport = true
            } catch { busy = nil; self.error = error.localizedDescription }
        }
    }

    func importGame(inspection: GameInspection, name: String, kind: GameKind, executable: String, usesYuri: Bool) {
        guard busy == nil else { return }
        showImport = false; busy = "正在复制游戏文件，较大的目录可能需要几分钟…"
        let paths = paths
        Task {
            do {
                let profile = try await Task.detached {
                    try GameImporter.importGame(inspection: inspection, name: name, kind: kind,
                        executable: executable, usesYuri: usesYuri, paths: paths)
                }.value
                var next = state; next.profiles.append(profile)
                do { try persist(next) }
                catch {
                    // Roll back only the newly created managed copy.
                    try? FileManager.default.removeItem(at: paths.game(profile.id))
                    throw error
                }
                select(profile.kind); selectedID = profile.id
                notice = "\(profile.name) 已导入，原游戏目录已保留。"
            } catch { self.error = error.localizedDescription }
            busy = nil
        }
    }

    func update(_ profile: GameProfile) {
        guard runningID != profile.id, let index = state.profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        var next = state; next.profiles[index] = profile
        do { try persist(next); editingProfile = nil } catch { self.error = error.localizedDescription }
    }

    func remove(_ profile: GameProfile) {
        guard runningID != profile.id else { return }
        let alert = NSAlert()
        alert.messageText = "将“\(profile.name)”移到废纸篓？"
        alert.informativeText = "客户端内的游戏副本与存档会移入废纸篓。原始导入目录不受影响。"
        alert.addButton(withTitle: "移到废纸篓"); alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            // Commit metadata after the game directory is safely in the Trash.
            let game = paths.game(profile.id)
            var trashed: NSURL?
            if FileManager.default.fileExists(atPath: game.path) { try FileManager.default.trashItem(at: game, resultingItemURL: &trashed) }
            var next = state; next.profiles.removeAll { $0.id == profile.id }
            do { try persist(next) }
            catch {
                if let trashed { try? FileManager.default.moveItem(at: trashed as URL, to: game) }
                throw error
            }
            let prefix = paths.prefix(profile.id)
            if FileManager.default.fileExists(atPath: prefix.path) { try FileManager.default.trashItem(at: prefix, resultingItemURL: nil) }
            selectedID = nil
        } catch { self.error = error.localizedDescription }
    }

    func installRuntime(archive: URL? = nil) {
        guard busy == nil, runningID == nil else { return }
        busy = "准备安装 Wine…"
        let paths = paths
        Task {
            do {
                try await RuntimeManager.install(paths: paths, archive: archive) { message in
                    Task { @MainActor in self.busy = message }
                }
                notice = "Wine 已安装。导入游戏后即可启动。"
            } catch { self.error = "安装未完成：\(error.localizedDescription)" }
            busy = nil; refreshEnvironment()
        }
    }

    func chooseWine() {
        let panel = NSOpenPanel(); panel.title = "选择 Wine 程序或 Wine.app"
        panel.canChooseFiles = true; panel.canChooseDirectories = false
        panel.treatsFilePackagesAsDirectories = false
        guard panel.runModal() == .OK, var url = panel.url else { return }
        if url.pathExtension == "app" { url.appendPathComponent("Contents/Resources/wine/bin/wine") }
        guard FileManager.default.isExecutableFile(atPath: url.path) else { error = "未找到可执行的 Wine。请选择 Wine Stable / Wine Devel.app，或 wine 可执行文件。"; return }
        var next = state; next.customWinePath = url.path
        do { try persist(next); refreshEnvironment() } catch { self.error = error.localizedDescription }
    }

    func installRosetta() {
        // Apple displays its terms in Terminal. The app never accepts them for the user.
        let script = paths.root.appendingPathComponent("Install Rosetta.command")
        do {
            try Data("#!/bin/zsh\n/usr/sbin/softwareupdate --install-rosetta\nprintf '\\n安装结束后，请回到红警作战中心点击「重新检测」。\\n'\n".utf8).write(to: script, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
            NSWorkspace.shared.open(script)
        } catch { self.error = error.localizedDescription }
    }

    func launch() {
        guard var profile = selectedProfile, busy == nil, runningID == nil else { return }
        guard let runtime, rosettaReady else { prepareAutomatically(thenLaunch: true); return }
        if profile.followsDisplay != false {
            let screen = NSApplication.shared.keyWindow?.screen ?? NSScreen.main
            if let screen {
                // Use logical desktop size, preserving readable RTS controls on Retina.
                profile.width = max(640, min(7680, Int(screen.frame.width) / 8 * 8))
                profile.height = max(480, min(4320, Int(screen.frame.height) / 8 * 8))
            }
        }
        runningID = profile.id; runMessage = "正在准备启动…"
        let log = paths.logs.appendingPathComponent("\(profile.id.uuidString)-\(Int(Date().timeIntervalSince1970)).log")
        logURL = log
        let paths = paths, compatibility = compatibility
        let header = "RedAlertMac 0.1.0\n版本：\(profile.name)\nWine：\(runtime.executable.path)\n程序：\(profile.executable)\n时间：\(Date())\n\n"
        do { try Data(header.utf8).write(to: log) } catch { runningID = nil; self.error = error.localizedDescription; return }
        Task {
            do {
                let (code, seconds) = try await runner.run(profile: profile, paths: paths, runtime: runtime,
                    compatibility: compatibility, log: log) { message in
                    Task { @MainActor in self.runMessage = message }
                }
                if seconds > 1, let index = state.profiles.firstIndex(where: { $0.id == profile.id }) {
                    var next = state; next.profiles[index].lastPlayed = Date(); next.profiles[index].playSeconds += seconds
                    try persist(next)
                }
                if code != 0 { error = "游戏进程退出，代码 \(code)。请打开启动日志检查缺失文件或运行环境问题。" }
                else if seconds < 5 { notice = "游戏进程已结束。若未看到游戏窗口，请查看日志；部分发行版本需要其原有平台或授权环境。" }
                else { notice = "游戏已退出，存档保存在这个版本的游戏目录中。" }
            } catch { self.error = error.localizedDescription }
            runningID = nil; runMessage = ""
        }
    }

    func stop() {
        Task { do { try await runner.stop() } catch { self.error = error.localizedDescription } }
    }

    func openLog() {
        if logURL == nil {
            logURL = (try? FileManager.default.contentsOfDirectory(at: paths.logs,
                includingPropertiesForKeys: [.contentModificationDateKey]))?.filter { $0.pathExtension == "log" }.sorted { $0.lastPathComponent > $1.lastPathComponent }.first
        }
        refreshLog(); showLog = true
    }
    func refreshLog() {
        guard let logURL else { logText = "尚无启动日志。导入并启动一个游戏后，这里会显示运行信息。"; return }
        do {
            let file = try FileHandle(forReadingFrom: logURL); defer { try? file.close() }
            let size = try file.seekToEnd(); if size > 256_000 { try file.seek(toOffset: size - 256_000) } else { try file.seek(toOffset: 0) }
            logText = String(decoding: try file.readToEnd() ?? Data(), as: UTF8.self)
        } catch { logText = "读取日志失败：\(error.localizedDescription)" }
    }
    func revealGame(_ profile: GameProfile) { NSWorkspace.shared.open(paths.game(profile.id)) }
}
