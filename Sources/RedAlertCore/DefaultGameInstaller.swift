import Foundation

public struct DownloadPackage: Sendable {
    public let name: String
    public let url: URL
    public let size: Int64
    public let sha256: String
    public init(name: String, url: String, size: Int64, sha256: String) {
        self.name = name; self.url = URL(string: url)!; self.size = size; self.sha256 = sha256
    }
}

/// Original XWIS distributions, plus an independently maintained Chinese language pack.
/// Packages are downloaded for the user's existing game license; no engine is reimplemented.
public enum DefaultGameInstaller {
    public static let redAlert2 = DownloadPackage(name: "Red-Alert-2-Multiplayer.exe",
        url: "https://web.archive.org/web/20130119120956id_/http://xwis.net/downloads/Red-Alert-2-Multiplayer.exe",
        size: 132913651, sha256: "f6127878003583c5e013ecc9020a622d1464224397c064d596905b1c005bfec6")
    public static let yuri = DownloadPackage(name: "Yuris-Revenge-Multiplayer.exe",
        url: "https://web.archive.org/web/20170612013942id_/http://xwis.net/downloads/Yuris-Revenge-Multiplayer.exe",
        size: 139427381, sha256: "28181e139b040c263490309ff9cef5bef77dadf1ecc938e6ef4298f46a2668ff")
    public static let chinese = DownloadPackage(name: "RedAlert2-LanguagePack-zh_hans-NoChineseAudio.zip",
        url: "https://github.com/Translate-with-LOVE/Ra2-zh_hans-main/releases/download/v25.8.11/RedAlert2-LanguagePack-zh_hans-NoChineseAudio.zip",
        size: 126185068, sha256: "6903b52f3e2c1b63811fe6f1f3305b9d9505ae8c28bb6e9a2885e3c9110d25e5")
    public static let music = DownloadPackage(name: "theme.mix",
        url: "https://web.archive.org/web/20150425075152id_/http://xwis.net/downloads/theme.mix",
        size: 76862662, sha256: "30027e29599d1c382ef4ca0bdc41590656c79715a46d7c4c68ae5ddfaed1fd4c")
    public static let yuriMusic = DownloadPackage(name: "thememd.mix",
        url: "https://web.archive.org/web/20150425062308id_/http://xwis.net/downloads/thememd.mix",
        size: 46859102, sha256: "8ac4ca1e48ce8f34cd1d5cf5b3a612dd045c97d320dcfd7d10c0c1e791dc19c5")
    public static let typeLibrary = DownloadPackage(name: "Ra2.tlb",
        url: "https://raw.githubusercontent.com/emuikernel/RedAlert2/master/Ra2.tlb",
        size: 30896, sha256: "8025e99820aa1d01a8acc0dbbdcfe83663a9102349fc87cd12d7839ee9d2faf4")
    public static let blowfishTypeLibrary = DownloadPackage(name: "Blowfish.tlb",
        url: "https://raw.githubusercontent.com/emuikernel/RedAlert2/master/Blowfish.tlb",
        size: 2348, sha256: "43f4c25c740281d405895917ab8024db742e87cbb35adf30707afff271eecbaa")
    public static let republicMod = DownloadPackage(name: "gonghui-20260220-3.zip",
        url: "https://mod.btfs.cn/mod/gonghui-20260220-3.zip",
        size: 2362218, sha256: "f5a9b9ab173404389d42dc65e9d83771c935b36fa9406a1b9dd4d02740504742")

    public static func cacheDirectory(paths: AppPaths) -> URL { paths.root.appendingPathComponent("Downloads", isDirectory: true) }

    public static func download(_ package: DownloadPackage, paths: AppPaths,
                                progress: @escaping @Sendable (String) -> Void) async throws -> URL {
        let cache = cacheDirectory(paths: paths)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let target = cache.appendingPathComponent(package.name)
        if FileManager.default.fileExists(atPath: target.path), try RuntimeManager.checksum(target) == package.sha256 { return target }
        progress("正在下载 \(package.name) · \(package.size / 1_048_576) MB…")
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120; config.timeoutIntervalForResource = 1800
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }
        var request = URLRequest(url: package.url)
        request.setValue("RedAlertMac/0.2", forHTTPHeaderField: "User-Agent")
        request.setValue("bytes=0-\(package.size - 1)", forHTTPHeaderField: "Range")
        let (temporary, response) = try await session.download(for: request)
        defer { try? FileManager.default.removeItem(at: temporary) }
        guard let status = (response as? HTTPURLResponse)?.statusCode, [200, 206].contains(status) else {
            throw RedAlertError.message("\(package.name) 下载失败。请检查网络后重试自动部署。")
        }
        let count = (try FileManager.default.attributesOfItem(atPath: temporary.path)[.size] as? NSNumber)?.int64Value
        guard count == package.size, try RuntimeManager.checksum(temporary) == package.sha256 else {
            throw RedAlertError.message("\(package.name) 文件校验失败，未使用此文件。请重试下载。")
        }
        try Data(contentsOf: temporary, options: .mappedIfSafe).write(to: target, options: .atomic)
        return target
    }

    public static func install(kind: GameKind, paths: AppPaths, extractor: URL, modFiles: URL? = nil,
                               progress: @escaping @Sendable (String) -> Void) async throws -> GameProfile {
        guard kind != .custom else { throw RedAlertError.message("自定义 MOD 请使用导入入口。") }
        let base = try await download(redAlert2, paths: paths, progress: progress)
        let translation = try await download(chinese, paths: paths, progress: progress)
        let theme = try await download(music, paths: paths, progress: progress)
        let tlb = try await download(typeLibrary, paths: paths, progress: progress)
        let blowfishTLB = try await download(blowfishTypeLibrary, paths: paths, progress: progress)
        let expansion = kind == .yurisRevenge ? try await download(yuri, paths: paths, progress: progress) : nil
        let expansionTheme = kind == .yurisRevenge ? try await download(yuriMusic, paths: paths, progress: progress) : nil
        let work = FileManager.default.temporaryDirectory.appendingPathComponent("redalert-deploy-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }
        let game = work.appendingPathComponent("Game")
        let log = paths.logs.appendingPathComponent("game-install.log")
        progress("正在解包并部署\(kind.title)的简体中文版…")
        let archives = [base, expansion, translation].compactMap { $0 }
        for archive in archives {
            let code = try await Task.detached {
                try Commands.run(extractor, ["x", archive.path, "-o\(game.path)", "-y", "-bb0"], log: log, timeout: 240)
            }.value
            guard code == 0 else { throw RedAlertError.message("\(archive.lastPathComponent) 解包失败。详情见安装日志。") }
        }
        for file in [theme, expansionTheme, tlb, blowfishTLB].compactMap({ $0 }) {
            let target = game.appendingPathComponent(file.lastPathComponent)
            if FileManager.default.fileExists(atPath: target.path) { try FileManager.default.removeItem(at: target) }
            try FileManager.default.copyItem(at: file, to: target)
        }
        if kind == .republic {
            let sourceDirectory: URL
            if let modFiles { sourceDirectory = modFiles }
            else {
                let archive = try await download(republicMod, paths: paths, progress: progress)
                sourceDirectory = work.appendingPathComponent("Republic")
                let extractionCode = try await Task.detached {
                    try Commands.run(extractor, ["x", archive.path, "-o\(sourceDirectory.path)", "-y", "-bb0"], log: log, timeout: 60)
                }.value
                guard extractionCode == 0 else { throw RedAlertError.message("共和国之辉 MOD 解包失败。") }
            }
            let files = try FileManager.default.contentsOfDirectory(at: sourceDirectory, includingPropertiesForKeys: nil)
            for name in ["ecache01.mix", "expand01.mix", "ra2.csf"] {
                guard let source = files.first(where: { $0.lastPathComponent.lowercased() == name }) else { throw RedAlertError.message("共和国之辉缺少 \(name)。") }
                let target = game.appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: target.path) { try FileManager.default.removeItem(at: target) }
                try FileManager.default.copyItem(at: source, to: target)
            }
        }
        guard let inspection = try GameImporter.inspect(game), let executable = inspection.recommendedExecutable(for: kind) else {
            throw RedAlertError.message("解包后未发现原版游戏程序。")
        }
        let profile = try GameImporter.importGame(inspection: inspection, name: "\(kind.title) · 简体中文版", kind: kind,
            executable: executable, usesYuri: kind == .yurisRevenge, paths: paths)
        let sourceInfo = "Original distribution: XWIS\nLanguage: Translate-with-LOVE v25.8.11\nModes: Skirmish / existing multiplayer services. Campaign media is not included.\n"
        try? Data(sourceInfo.utf8).write(to: paths.game(profile.id).appendingPathComponent("版本来源.txt"))
        return profile
    }
}
