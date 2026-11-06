import Foundation
import CryptoKit

public enum Commands {
    /// Uses argument arrays, never a shell. Output goes to a file to avoid pipe deadlocks.
    public static func run(_ executable: URL, _ arguments: [String], environment: [String: String]? = nil,
                           directory: URL? = nil, log: URL? = nil, timeout: Double = 180) throws -> Int32 {
        let process = Process()
        process.executableURL = executable; process.arguments = arguments
        process.environment = environment; process.currentDirectoryURL = directory
        var handle: FileHandle?
        if let log {
            if !FileManager.default.fileExists(atPath: log.path) { FileManager.default.createFile(atPath: log.path, contents: nil) }
            handle = try FileHandle(forWritingTo: log); try handle?.seekToEnd()
            process.standardOutput = handle; process.standardError = handle
        } else {
            process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        }
        defer { try? handle?.close() }
        try process.run()
        let timer = DispatchSource.makeTimerSource(queue: .global())
        timer.schedule(deadline: .now() + timeout)
        timer.setEventHandler { if process.isRunning { process.terminate() } }
        timer.resume()
        process.waitUntilExit(); timer.cancel()
        return process.terminationStatus
    }
}

public struct WineRuntime: Identifiable, Equatable, Sendable {
    public var id: String { executable.path }
    public let executable: URL
    public let name: String
    public var server: URL { executable.deletingLastPathComponent().appendingPathComponent("wineserver") }
    public init(executable: URL, name: String) { self.executable = executable; self.name = name }
}

public enum RuntimeManager {
    public static let releaseVersion = "11.21"
    public static let releaseURL = URL(string: "https://github.com/Gcenx/macOS_Wine_builds/releases/download/11.21/wine-devel-11.21-osx64.tar.xz")!
    public static let releaseSHA256 = "9909b486657e10ab66c7279371ae1f990345b596b3b1b3a0cf21f28af24fa0ce"
    public static let managedBundleName = "Wine Devel.app"

    public static var isAppleSilicon: Bool {
        var value: Int32 = 0; var size = MemoryLayout<Int32>.size
        return sysctlbyname("hw.optional.arm64", &value, &size, nil, 0) == 0 && value == 1
    }
    public static var rosettaAvailable: Bool {
        !isAppleSilicon || (try? Commands.run(URL(fileURLWithPath: "/usr/bin/arch"), ["-x86_64", "/usr/bin/true"], timeout: 10)) == 0
    }

    public static func detect(paths: AppPaths, customPath: String? = nil) -> [WineRuntime] {
        var candidates: [(String, String)] = []
        if let customPath, !customPath.isEmpty { candidates.append((customPath, "自选 Wine")) }
        for root in [paths.runtimes.path, "/Applications", FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path] {
            for name in ["Wine Devel", "Wine Stable", "Wine Staging"] {
                candidates.append(("\(root)/\(name).app/Contents/Resources/wine/bin/wine", name + (root == paths.runtimes.path ? " · 托管" : "")))
            }
        }
        for binary in ["/opt/homebrew/bin/wine", "/usr/local/bin/wine", "/opt/local/bin/wine"] {
            candidates.append((binary, "Wine · 系统"))
        }
        var seen = Set<String>()
        return candidates.compactMap { path, name in
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.isExecutableFile(atPath: path), seen.insert(url.resolvingSymlinksInPath().path).inserted else { return nil }
            return WineRuntime(executable: url, name: name)
        }
    }

    public static func checksum(_ url: URL) throws -> String {
        let file = try FileHandle(forReadingFrom: url); defer { try? file.close() }
        var hash = SHA256()
        while let chunk = try file.read(upToCount: 1024 * 1024), !chunk.isEmpty { hash.update(data: chunk) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }

    public static func install(paths: AppPaths, archive: URL? = nil,
                               progress: @escaping @Sendable (String) -> Void) async throws {
        try paths.prepare()
        let work = paths.runtimes.appendingPathComponent(".install-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }
        let tarball: URL
        if let archive { tarball = archive }
        else {
            progress("正在下载 Wine 11.21（约 215 MB），请保持联网…")
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 90; config.timeoutIntervalForResource = 1800
            let session = URLSession(configuration: config)
            defer { session.finishTasksAndInvalidate() }
            let (temp, response) = try await session.download(from: releaseURL)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw RedAlertError.message("Wine 下载失败，请稍后重试或手动选择 Wine。") }
            tarball = work.appendingPathComponent("wine.tar.xz")
            try FileManager.default.moveItem(at: temp, to: tarball)
        }
        progress("正在校验 Wine 安装包…")
        guard try checksum(tarball) == releaseSHA256 else { throw RedAlertError.message("Wine 安装包 SHA-256 校验失败，已取消安装。") }
        progress("正在解压运行环境…")
        let extraction = work.appendingPathComponent("extracted")
        try FileManager.default.createDirectory(at: extraction, withIntermediateDirectories: true)
        let code = try await Task.detached {
            try Commands.run(URL(fileURLWithPath: "/usr/bin/tar"), ["-xf", tarball.path, "-C", extraction.path], timeout: 240)
        }.value
        guard code == 0 else { throw RedAlertError.message("Wine 解压失败，请检查可用空间。") }
        let unpacked = extraction.appendingPathComponent(managedBundleName)
        guard FileManager.default.isExecutableFile(atPath: unpacked.appendingPathComponent("Contents/Resources/wine/bin/wine").path) else {
            throw RedAlertError.message("安装包中未找到 Wine 程序。")
        }
        let destination = paths.runtimes.appendingPathComponent(managedBundleName)
        // Never remove a working runtime before a complete new bundle is ready.
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw RedAlertError.message("托管 Wine 已存在。可直接使用，或在访达中管理运行环境。")
        }
        try FileManager.default.moveItem(at: unpacked, to: destination)
        progress("Wine 运行环境已安装")
    }

    public static func environment(runtime: WineRuntime, prefix: URL, useDDraw: Bool = false) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["WINEPREFIX"] = prefix.path
        // Modern macOS Wine uses WoW64; WINEARCH=win32 is not supported.
        env.removeValue(forKey: "WINEARCH")
        env["WINEDEBUG"] = "-all,err+all"
        env["MVK_CONFIG_LOG_LEVEL"] = "1"
        env["WINEDLLOVERRIDES"] = useDDraw ? "ddraw=n,b;winemenubuilder.exe=d" : "winemenubuilder.exe=d"
        env["PATH"] = runtime.executable.deletingLastPathComponent().path + ":/usr/bin:/bin:/usr/sbin:/sbin"
        // Prevent Wine from inheriting injected developer libraries.
        env.removeValue(forKey: "DYLD_INSERT_LIBRARIES")
        return env
    }

    public static func ensureReady(paths: AppPaths, customPath: String? = nil,
                                   progress: @escaping @Sendable (String) -> Void) async throws -> WineRuntime {
        try paths.prepare()
        if !rosettaAvailable {
            progress("正在自动安装 Apple Rosetta 兼容组件…")
            let log = paths.logs.appendingPathComponent("environment-setup.log")
            let code = try await Task.detached {
                try Commands.run(URL(fileURLWithPath: "/usr/sbin/softwareupdate"),
                    ["--install-rosetta", "--agree-to-license"], log: log, timeout: 600)
            }.value
            guard code == 0, rosettaAvailable else { throw RedAlertError.message("系统兼容组件安装未完成。请检查网络后点击「重试自动准备」。详情见环境日志。") }
        }
        if detect(paths: paths, customPath: customPath).isEmpty { try await install(paths: paths, progress: progress) }
        guard let runtime = detect(paths: paths, customPath: customPath).first else { throw RedAlertError.message("自动安装后未找到 Wine，请重试。") }
        let marker = paths.root.appendingPathComponent("verified-runtime.txt")
        let fingerprint = runtime.executable.resolvingSymlinksInPath().path + "|" + releaseVersion
        if (try? String(contentsOf: marker, encoding: .utf8)) != fingerprint {
            progress("正在自动验证 32 位游戏运行能力…")
            let log = paths.logs.appendingPathComponent("runtime-probe.log")
            let prefix = paths.root.appendingPathComponent("DiagnosticPrefix")
            let env = environment(runtime: runtime, prefix: prefix)
            let passed = try await Task.detached {
                try Data().write(to: log)
                guard try Commands.run(runtime.executable, ["wineboot", "-u"], environment: env, log: log, timeout: 240) == 0 else { return false }
                let code = try Commands.run(runtime.executable, ["C:\\windows\\syswow64\\cmd.exe", "/c", "echo", "REDALERT_WOW64_OK"], environment: env, log: log, timeout: 60)
                let output = String(decoding: try Data(contentsOf: log), as: UTF8.self)
                return code == 0 && output.contains("REDALERT_WOW64_OK")
            }.value
            guard passed else { throw RedAlertError.message("32 位兼容检查未通过，请查看运行环境日志后重试自动准备。") }
            try Data(fingerprint.utf8).write(to: marker, options: .atomic)
        }
        return runtime
    }
}
