import Foundation

public struct GameInspection: Identifiable, Sendable {
    public var id: String { directory.path }
    public let directory: URL
    public let files: [String: String]
    public let executables: [String]
    public let detectedKinds: [GameKind]
    public var hasYuri: Bool { files["ra2md.mix"] != nil }
    public func recommendedExecutable(for kind: GameKind) -> String? {
        kind.executableCandidates.compactMap { files[$0] }.first ?? (kind == .custom ? executables.first : nil)
    }
    public func missingFiles(for kind: GameKind, usesYuri: Bool = false) -> [String] {
        var required = ["ra2.mix", "language.mix"]
        if kind == .yurisRevenge || usesYuri { required += ["ra2md.mix", "langmd.mix"] }
        return required.filter { files[$0] == nil }
    }
}

public enum GameImporter {
    public static func inspect(_ directory: URL) throws -> GameInspection? {
        let entries = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isRegularFileKey])
        var files: [String: String] = [:]
        for entry in entries where (try? entry.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
            let key = entry.lastPathComponent.lowercased()
            if let existing = files[key], existing != entry.lastPathComponent {
                throw RedAlertError.message("目录中存在 Windows 无法区分的同名文件：\(existing) / \(entry.lastPathComponent)。")
            }
            files[key] = entry.lastPathComponent
        }
        let executables = files.values.filter { $0.lowercased().hasSuffix(".exe") }.sorted()
        guard files["ra2.mix"] != nil || files["gamemd.exe"] != nil || files["ra2.exe"] != nil || files["game.exe"] != nil else { return nil }
        var kinds: [GameKind] = []
        if GameKind.redAlert2.executableCandidates.contains(where: { files[$0] != nil }) { kinds.append(.redAlert2) }
        if GameKind.yurisRevenge.executableCandidates.contains(where: { files[$0] != nil }) { kinds.append(.yurisRevenge) }
        return GameInspection(directory: directory, files: files, executables: executables, detectedKinds: kinds)
    }

    public static func discover(in directory: URL) throws -> [GameInspection] {
        if let direct = try inspect(directory) { return [direct] }
        var results: [GameInspection] = []
        var queue: [(URL, Int)] = [(directory, 0)]
        var visited = 0
        while !queue.isEmpty && visited < 500 {
            let (current, depth) = queue.removeFirst(); visited += 1
            guard depth < 3 else { continue }
            let entries = (try? FileManager.default.contentsOfDirectory(at: current,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles])) ?? []
            for entry in entries {
                let values = try? entry.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                guard values?.isDirectory == true, values?.isSymbolicLink != true else { continue }
                if let match = try inspect(entry) { results.append(match) }
                else { queue.append((entry, depth + 1)) }
            }
        }
        return results.sorted { $0.directory.path < $1.directory.path }
    }

    public static func validateExecutable(_ url: URL) throws {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        guard let header = try handle.read(upToCount: 64), header.count >= 64,
              header[0] == 0x4d, header[1] == 0x5a else {
            throw RedAlertError.message("\(url.lastPathComponent) 不是有效的 Windows 程序。请选择原版 EXE 文件。")
        }
        let offset = header[60..<64].enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << (8 * $1.offset) }
        guard offset < 64 * 1024 * 1024 else { throw RedAlertError.message("Windows EXE 文件头已损坏。") }
        try handle.seek(toOffset: UInt64(offset))
        guard try handle.read(upToCount: 4) == Data([0x50, 0x45, 0, 0]) else {
            throw RedAlertError.message("\(url.lastPathComponent) 缺少 PE 文件头，可能不是完整的游戏程序。")
        }
    }

    public static func importGame(inspection: GameInspection, name: String, kind: GameKind,
                                  executable: String, usesYuri: Bool, paths: AppPaths) throws -> GameProfile {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw RedAlertError.message("请为这个版本起一个名字。") }
        guard inspection.executables.contains(executable), !executable.contains("/") else {
            throw RedAlertError.message("请选择游戏目录中的启动程序。")
        }
        let missing = inspection.missingFiles(for: kind, usesYuri: usesYuri)
        guard missing.isEmpty else { throw RedAlertError.message("游戏目录不完整，缺少：\(missing.joined(separator: "、"))。请导入已安装的完整游戏。") }
        try validateExecutable(inspection.directory.appendingPathComponent(executable))
        let source = inspection.directory.resolvingSymlinksInPath().standardizedFileURL
        let managed = paths.root.resolvingSymlinksInPath().standardizedFileURL
        guard source != managed, !managed.path.hasPrefix(source.path + "/"),
              !source.path.hasPrefix(managed.path + "/") else {
            throw RedAlertError.message("请选择客户端游戏库以外的原始游戏目录。")
        }
        // A copied profile must be self-contained, including its future save files.
        if let iterator = FileManager.default.enumerator(at: source, includingPropertiesForKeys: [.isSymbolicLinkKey]) {
            for case let file as URL in iterator {
                if (try? file.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
                    throw RedAlertError.message("游戏目录包含符号链接 \(file.lastPathComponent)，请先将它替换为实际文件。")
                }
            }
        }
        try paths.prepare()
        let profile = GameProfile(name: name, kind: kind, executable: executable, usesYuri: usesYuri)
        let stage = paths.games.appendingPathComponent(".import-\(profile.id.uuidString)")
        do {
            try FileManager.default.copyItem(at: source, to: stage)
            try FileManager.default.moveItem(at: stage, to: paths.game(profile.id))
        } catch {
            try? FileManager.default.removeItem(at: stage)
            throw error
        }
        return profile
    }
}
