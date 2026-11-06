import Foundation
import RedAlertCore

@main struct CLI {
    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let paths = AppPaths(root: ProcessInfo.processInfo.environment["REDALERT_DATA_DIR"].map { URL(fileURLWithPath: $0) })
        do {
            switch arguments.first {
            case "environment":
                let state = try LibraryStore(paths: paths).load()
                let report: [String: Any] = [
                    "appleSilicon": RuntimeManager.isAppleSilicon,
                    "rosettaAvailable": RuntimeManager.rosettaAvailable,
                    "wine": RuntimeManager.detect(paths: paths, customPath: state.customWinePath).map { ["name": $0.name, "path": $0.executable.path] },
                    "library": paths.library.path, "profiles": state.profiles.count
                ]
                print(String(decoding: try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]), as: UTF8.self))
            case "inspect":
                guard arguments.count == 2 else { throw RedAlertError.message("用法：redalertctl inspect /path/to/game") }
                let results = try GameImporter.discover(in: URL(fileURLWithPath: arguments[1]))
                guard !results.isEmpty else { throw RedAlertError.message("未找到红警 2 游戏目录。") }
                for item in results {
                    print("目录：\(item.directory.path)\n程序：\(item.executables.joined(separator: ", "))")
                    print("版本：\(item.detectedKinds.map(\.title).joined(separator: ", "))")
                    print("红警 2 缺失：\(item.missingFiles(for: .redAlert2))\n尤里缺失：\(item.missingFiles(for: .yurisRevenge))")
                }
            case "install-wine":
                let archive = arguments.count > 1 ? URL(fileURLWithPath: arguments[1]) : nil
                try await RuntimeManager.install(paths: paths, archive: archive) { print($0) }
                print("Wine 已安装；Apple Silicon Mac 还需 Rosetta。")
            case "probe":
                guard RuntimeManager.rosettaAvailable else { throw RedAlertError.message("尚未安装 Rosetta。请通过客户端的 Apple 安装入口完成安装。") }
                let state = try LibraryStore(paths: paths).load()
                guard let runtime = RuntimeManager.detect(paths: paths, customPath: state.customWinePath).first else { throw RedAlertError.message("未检测到 Wine。") }
                try paths.prepare()
                let prefix = paths.root.appendingPathComponent("DiagnosticPrefix")
                let env = RuntimeManager.environment(runtime: runtime, prefix: prefix)
                let log = paths.logs.appendingPathComponent("runtime-probe.log")
                try Data().write(to: log)
                guard try Commands.run(runtime.executable, ["wineboot", "-u"], environment: env, log: log, timeout: 240) == 0 else {
                    throw RedAlertError.message("Wine 初始化失败，请查看 \(log.path)")
                }
                let code = try Commands.run(runtime.executable, ["C:\\windows\\syswow64\\cmd.exe", "/c", "echo", "REDALERT_WOW64_OK"], environment: env, log: log, timeout: 60)
                let output = String(decoding: try Data(contentsOf: log), as: UTF8.self)
                guard code == 0, output.contains("REDALERT_WOW64_OK") else { throw RedAlertError.message("32 位 Windows 程序测试失败，请查看 \(log.path)") }
                print("Wine WoW64 测试通过：可运行 32 位 Windows cmd.exe。此检查不代表已验证游戏。\n日志：\(log.path)")
            case "import":
                guard arguments.count >= 3, let kind = GameKind(rawValue: arguments[1]) else {
                    throw RedAlertError.message("用法：redalertctl import <redAlert2|yurisRevenge|republic|custom> <目录> [名称]")
                }
                let source = URL(fileURLWithPath: arguments[2])
                guard let inspection = try GameImporter.inspect(source), let executable = inspection.recommendedExecutable(for: kind) else {
                    throw RedAlertError.message("目录中未找到相应版本的程序。")
                }
                let profile = try GameImporter.importGame(inspection: inspection, name: arguments.count > 3 ? arguments[3] : kind.title,
                    kind: kind, executable: executable, usesYuri: kind == .yurisRevenge, paths: paths)
                var state = try LibraryStore(paths: paths).load(); state.profiles.append(profile)
                try LibraryStore(paths: paths).save(state)
                print("已导入 \(profile.name)：\(profile.id.uuidString)")
            case "deploy":
                guard arguments.count == 3, let kind = GameKind(rawValue: arguments[1]) else { throw RedAlertError.message("用法：redalertctl deploy <类型> <7zz路径>") }
                let profile = try await DefaultGameInstaller.install(kind: kind, paths: paths,
                    extractor: URL(fileURLWithPath: arguments[2])) { print($0) }
                var state = try LibraryStore(paths: paths).load(); state.profiles.append(profile)
                do { try LibraryStore(paths: paths).save(state) }
                catch { try? FileManager.default.removeItem(at: paths.game(profile.id)); throw error }
                print("已部署 \(profile.name)：\(profile.id.uuidString)")
            case "launch":
                guard arguments.count == 3, let id = UUID(uuidString: arguments[1]) else { throw RedAlertError.message("用法：redalertctl launch <档案UUID> <兼容补丁目录>") }
                let state = try LibraryStore(paths: paths).load()
                guard let profile = state.profiles.first(where: { $0.id == id }) else { throw RedAlertError.message("未找到游戏档案。") }
                let runtime = try await RuntimeManager.ensureReady(paths: paths, customPath: state.customWinePath) { print($0) }
                let log = paths.logs.appendingPathComponent("validation-\(id.uuidString).log")
                let runner = GameRunner()
                let result = try await runner.run(profile: profile, paths: paths, runtime: runtime,
                    compatibility: URL(fileURLWithPath: arguments[2]), log: log) { print($0) }
                print("退出代码：\(result.0)，运行秒数：\(result.1)，日志：\(log.path)")
            default:
                print("redalertctl environment | inspect <游戏目录> | import <类型> <目录> [名称] | launch <UUID> <补丁目录> | install-wine [官方tar.xz] | probe")
            }
        } catch {
            FileHandle.standardError.write(Data("错误：\(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
}
