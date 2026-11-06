import Foundation

public enum GameConfiguration {
    public static func prepare(profile: GameProfile, paths: AppPaths, compatibility: URL) throws {
        let game = paths.game(profile.id)
        guard let inspection = try GameImporter.inspect(game) else { throw RedAlertError.message("游戏目录不存在或已被移动，请重新导入。") }
        guard !profile.executable.contains("/"), !profile.executable.contains("\\"),
              inspection.executables.contains(profile.executable) else { throw RedAlertError.message("找不到所选启动程序，请检查版本设置。") }
        try GameImporter.validateExecutable(game.appendingPathComponent(profile.executable))
        let missing = inspection.missingFiles(for: profile.kind, usesYuri: profile.usesYuri)
        guard missing.isEmpty else { throw RedAlertError.message("游戏文件缺失：\(missing.joined(separator: "、"))。") }
        guard (640...7680).contains(profile.width), (480...4320).contains(profile.height) else { throw RedAlertError.message("游戏分辨率超出可用范围。") }
        guard profile.useCompatibilityPatch else { return }
        let backup = game.appendingPathComponent(".redalert-backup", isDirectory: true)
        try FileManager.default.createDirectory(at: backup, withIntermediateDirectories: true)
        let dll = game.appendingPathComponent(inspection.files["ddraw.dll"] ?? "ddraw.dll")
        let iniName = profile.usesYuri ? "ra2md.ini" : "ra2.ini"
        let gameINI = game.appendingPathComponent(inspection.files[iniName] ?? iniName)
        let drawINI = game.appendingPathComponent(inspection.files["ddraw.ini"] ?? "ddraw.ini")
        let bundledDLL = compatibility.appendingPathComponent("ddraw.dll")
        guard FileManager.default.fileExists(atPath: bundledDLL.path) else { throw RedAlertError.message("客户端缺少 cnc-ddraw 补丁，请重新构建客户端。") }
        let manifestURL = backup.appendingPathComponent("original-files.json")
        var originals = FileManager.default.fileExists(atPath: manifestURL.path)
            ? try JSONDecoder().decode([String: Bool].self, from: Data(contentsOf: manifestURL)) : [:]
        for file in [dll, gameINI, drawINI] where originals[file.lastPathComponent] == nil {
            let exists = FileManager.default.fileExists(atPath: file.path)
            originals[file.lastPathComponent] = exists
            if exists {
                let target = backup.appendingPathComponent(file.lastPathComponent)
                if !FileManager.default.fileExists(atPath: target.path) { try FileManager.default.copyItem(at: file, to: target) }
            }
        }
        try JSONEncoder().encode(originals).write(to: manifestURL, options: .atomic)
        try Data(contentsOf: bundledDLL).write(to: dll, options: .atomic)
        try INIEditor.updateFile(gameINI, sections: ["Video": [
            "ScreenWidth": String(profile.width), "ScreenHeight": String(profile.height),
            "VideoBackBuffer": "no", "AllowHiResModes": "yes", "AllowVRAMSidebar": "no", "StretchMovies": "no"
        ]], backupRoot: backup)
        // The game itself stays fullscreen; cnc-ddraw controls the actual Mac window.
        let displaySettings = [
            "renderer": profile.renderer, "windowed": profile.displayMode == .fullscreen ? "false" : "true",
            "border": profile.displayMode == .borderless ? "false" : "true",
            "fullscreen": profile.displayMode == .borderless ? "true" : "false",
            "width": profile.displayMode == .windowed ? String(profile.width) : "0",
            "height": profile.displayMode == .windowed ? String(profile.height) : "0",
            "maintas": "true", "boxing": "false", "maxfps": "60", "vsync": "true",
            "adjmouse": "true", "devmode": "false", "savesettings": "0",
            "posX": "-32000", "posY": "-32000", "toggle_borderless": "true"
        ]
        var sections = ["ddraw": displaySettings]
        for executable in ["game", "ra2", "gamemd", "ra2md", "gamemd-spawn", "Red Alert 2", "Yuri's Revenge"] {
            var specific = displaySettings
            specific["tshack"] = "true"; specific["noactivateapp"] = "true"; specific["minfps"] = "-1"
            sections[executable] = specific
        }
        let template = try? Data(contentsOf: compatibility.appendingPathComponent("ddraw.ini"))
        try INIEditor.updateFile(drawINI, sections: sections, backupRoot: backup, template: template)
    }

    public static func restore(profile: GameProfile, paths: AppPaths) throws {
        let game = paths.game(profile.id), backup = game.appendingPathComponent(".redalert-backup")
        guard FileManager.default.fileExists(atPath: backup.path) else { return }
        let manifestURL = backup.appendingPathComponent("original-files.json")
        let originals = try JSONDecoder().decode([String: Bool].self, from: Data(contentsOf: manifestURL))
        for (name, existed) in originals {
            guard !name.contains("/"), !name.contains("\\"), name != ".", name != ".." else { throw RedAlertError.message("显示文件备份记录无效。") }
            let target = game.appendingPathComponent(name)
            if existed { try Data(contentsOf: backup.appendingPathComponent(name)).write(to: target, options: .atomic) }
            else if FileManager.default.fileExists(atPath: target.path) { try FileManager.default.removeItem(at: target) }
        }
        try FileManager.default.removeItem(at: backup)
    }
}

public actor GameRunner {
    private var activeRuntime: WineRuntime?
    private var activePrefix: URL?
    private var gameProcess: Process?
    private var stopRequested = false
    public init() {}

    public func run(profile: GameProfile, paths: AppPaths, runtime: WineRuntime, compatibility: URL,
                    log: URL, progress: @escaping @Sendable (String) -> Void) async throws -> (Int32, Double) {
        guard activePrefix == nil else { throw RedAlertError.message("已有游戏正在运行。请先退出当前游戏。") }
        guard RuntimeManager.rosettaAvailable else { throw RedAlertError.message("此 Apple Silicon Mac 尚未安装 Rosetta。请前往「运行环境」完成安装。") }
        activeRuntime = runtime; activePrefix = paths.prefix(profile.id); stopRequested = false
        defer { activeRuntime = nil; activePrefix = nil; gameProcess = nil }
        try paths.prepare()
        let prefix = paths.prefix(profile.id)
        let env = RuntimeManager.environment(runtime: runtime, prefix: prefix)
        let game = paths.game(profile.id)
        progress("正在检查游戏与显示设置…")
        try GameConfiguration.prepare(profile: profile, paths: paths, compatibility: compatibility)
        guard !stopRequested else { return (0, 0) }
        if !FileManager.default.fileExists(atPath: prefix.appendingPathComponent("system.reg").path) {
            progress("首次启动：正在创建独立 Windows 环境…")
            let code = try await Task.detached {
                try Commands.run(runtime.executable, ["wineboot", "-u"], environment: env, log: log, timeout: 240)
            }.value
            guard !stopRequested else { return (0, 0) }
            guard code == 0 else { throw RedAlertError.message("Wine 环境初始化失败（\(code)）。请查看启动日志。") }
        }
        // Westwood expects its installation directory in the registry.
        let windowsPath = "Z:" + game.path.replacingOccurrences(of: "/", with: "\\")
        for product in ["Red Alert 2", "Yuri's Revenge"] {
            let key = "HKLM\\Software\\Westwood\\\(product)"
            let code = try await Task.detached {
                try Commands.run(runtime.executable, ["reg", "add", key, "/v", "InstallPath", "/t", "REG_SZ", "/d", windowsPath, "/f", "/reg:32"],
                                 environment: env, log: log, timeout: 40)
            }.value
            guard code == 0 else { throw RedAlertError.message("写入游戏安装路径失败（\(code)），请查看启动日志。") }
            guard !stopRequested else { return (0, 0) }
        }
        if let inspection = try GameImporter.inspect(game), let blowfishName = inspection.files["blowfish.dll"] {
            progress("正在注册原版游戏组件…")
            let dllPath = "Z:" + game.appendingPathComponent(blowfishName).path.replacingOccurrences(of: "/", with: "\\")
            let registrationCode = try await Task.detached {
                try Commands.run(runtime.executable, ["C:\\windows\\syswow64\\regsvr32.exe", "/s", dllPath],
                    environment: env, directory: game, log: log, timeout: 60)
            }.value
            guard registrationCode == 0 else { throw RedAlertError.message("原版 Blowfish 组件注册失败（\(registrationCode)），请查看启动日志。") }
        }
        guard !stopRequested else { return (0, 0) }
        let process = Process()
        process.executableURL = runtime.executable
        process.arguments = [game.appendingPathComponent(profile.executable).path] + profile.arguments
        process.environment = RuntimeManager.environment(runtime: runtime, prefix: prefix, useDDraw: profile.useCompatibilityPatch)
        process.currentDirectoryURL = game
        if !FileManager.default.fileExists(atPath: log.path) { FileManager.default.createFile(atPath: log.path, contents: nil) }
        let handle = try FileHandle(forWritingTo: log); try handle.seekToEnd()
        defer { try? handle.close() }
        process.standardOutput = handle; process.standardError = handle
        gameProcess = process
        let start = Date()
        progress("正在启动原版游戏…")
        let code: Int32 = try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { child in continuation.resume(returning: child.terminationStatus) }
            do {
                try process.run()
                progress("原版游戏运行中 · Ctrl + Tab 释放鼠标")
            } catch { process.terminationHandler = nil; continuation.resume(throwing: error) }
        }
        if code == 0, !stopRequested, FileManager.default.isExecutableFile(atPath: runtime.server.path) {
            // Launcher EXEs may spawn the actual game and exit. Track the entire isolated prefix.
            _ = try await Task.detached {
                try Commands.run(runtime.server, ["-w"], environment: env, log: log, timeout: 7 * 24 * 3600)
            }.value
        }
        return (stopRequested ? 0 : code, Date().timeIntervalSince(start))
    }

    public func stop() async throws {
        stopRequested = true
        guard let runtime = activeRuntime, let prefix = activePrefix else { return }
        if FileManager.default.isExecutableFile(atPath: runtime.server.path) {
            let env = RuntimeManager.environment(runtime: runtime, prefix: prefix)
            let code = try await Task.detached {
                try Commands.run(runtime.server, ["-k"], environment: env, timeout: 15)
            }.value
            guard code == 0 else { throw RedAlertError.message("退出游戏失败，请在游戏内退出后重试。") }
        }
        if let gameProcess, gameProcess.isRunning { gameProcess.terminate() }
    }
}
