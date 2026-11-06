import Foundation

/// Changes only ASCII INI keys. All unrelated bytes, including GBK text, survive.
public enum INIEditor {
    public static func patch(_ data: Data, sections: [String: [String: String]]) throws -> Data {
        guard !data.starts(with: [0xff, 0xfe]), !data.starts(with: [0xfe, 0xff]) else {
            throw RedAlertError.message("INI 使用 UTF-16 编码，请先转换为游戏支持的 ANSI 编码。")
        }
        let hasBOM = data.starts(with: [0xef, 0xbb, 0xbf])
        let input = hasBOM ? Data(data.dropFirst(3)) : data
        let crlf = input.contains(13)
        var lines = input.split(separator: 10, omittingEmptySubsequences: false).map { line -> [UInt8] in
            var bytes = Array(line); if bytes.last == 13 { bytes.removeLast() }; return bytes
        }
        if lines.last?.isEmpty == true { lines.removeLast() }
        func text(_ line: [UInt8]) -> String { String(bytes: line, encoding: .ascii)?.trimmingCharacters(in: .whitespaces) ?? "" }
        for (section, settings) in sections.sorted(by: { $0.key < $1.key }) {
            let expected = "[\(section.lowercased())]"
            if let start = lines.firstIndex(where: { text($0).lowercased() == expected }) {
                let end = ((start + 1)..<lines.count).first(where: { text(lines[$0]).hasPrefix("[") }) ?? lines.count
                var seen = Set<String>()
                let lower = Dictionary(uniqueKeysWithValues: settings.map { ($0.key.lowercased(), ($0.key, $0.value)) })
                var replacement: [[UInt8]] = []
                for line in lines[(start + 1)..<end] {
                    let content = text(line)
                    let key = content.split(separator: "=", maxSplits: 1).first.map { $0.trimmingCharacters(in: .whitespaces).lowercased() } ?? ""
                    if !content.hasPrefix(";"), let (displayKey, value) = lower[key] {
                        if seen.insert(key).inserted { replacement.append(Array("\(displayKey)=\(value)".utf8)) }
                    } else { replacement.append(line) }
                }
                for (key, value) in settings.sorted(by: { $0.key < $1.key }) where !seen.contains(key.lowercased()) {
                    replacement.append(Array("\(key)=\(value)".utf8))
                }
                lines.replaceSubrange((start + 1)..<end, with: replacement)
            } else {
                if !lines.isEmpty { lines.append([]) }
                lines.append(Array("[\(section)]".utf8))
                for (key, value) in settings.sorted(by: { $0.key < $1.key }) { lines.append(Array("\(key)=\(value)".utf8)) }
            }
        }
        var result = hasBOM ? Data([0xef, 0xbb, 0xbf]) : Data()
        for line in lines { result.append(contentsOf: line); result.append(contentsOf: crlf ? [13, 10] : [10]) }
        return result
    }

    public static func updateFile(_ url: URL, sections: [String: [String: String]], backupRoot: URL, template: Data? = nil) throws {
        let fm = FileManager.default
        let exists = fm.fileExists(atPath: url.path)
        let original = exists ? try Data(contentsOf: url) : (template ?? Data())
        let output = try patch(original, sections: sections)
        if exists {
            try fm.createDirectory(at: backupRoot, withIntermediateDirectories: true)
            let backup = backupRoot.appendingPathComponent(url.lastPathComponent)
            if !fm.fileExists(atPath: backup.path) { try original.write(to: backup, options: .atomic) }
        }
        try output.write(to: url, options: .atomic)
    }
}
