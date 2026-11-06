import Foundation

struct CheckFailure: Error, CustomStringConvertible {
    let description: String
}
func checkEqual<T: Equatable>(_ lhs: T, _ rhs: T, file: String = #fileID, line: Int = #line) throws {
    if lhs != rhs { throw CheckFailure(description: "\(file):\(line): expected \(rhs), got \(lhs)") }
}
func checkTrue(_ condition: Bool, file: String = #fileID, line: Int = #line) throws {
    if !condition { throw CheckFailure(description: "\(file):\(line): expected true") }
}
func checkFalse(_ condition: Bool, file: String = #fileID, line: Int = #line) throws {
    try checkTrue(!condition, file: file, line: line)
}
func checkNil<T>(_ value: T?, file: String = #fileID, line: Int = #line) throws {
    if value != nil { throw CheckFailure(description: "\(file):\(line): expected nil") }
}
func unwrap<T>(_ value: T?, file: String = #fileID, line: Int = #line) throws -> T {
    guard let value else { throw CheckFailure(description: "\(file):\(line): expected a value") }
    return value
}
func expectThrows<T>(_ expression: @autoclosure () throws -> T, file: String = #fileID, line: Int = #line) throws {
    do { _ = try expression() } catch { return }
    throw CheckFailure(description: "\(file):\(line): expected an error")
}

@main struct ChecksRunner {
    static func main() {
        let suite = CoreTests()
        let checks: [(String, () throws -> Void)] = [
            ("大小写识别与双版本目录", suite.testMixedCaseDirectorySupportsBothVersions),
            ("尤里资料片资源检查", suite.testYuriRequiresExpansionAssets),
            ("解压包装目录递归识别", suite.testFindsGameInsideExtractedWrapper),
            ("损坏 EXE 导入前拦截", suite.testRejectsCorruptExecutableBeforeImport),
            ("独立导入 → 持久化 → 配置 → 备份恢复", suite.testImportIsolationPersistenceConfigurationAndRestore),
            ("外部符号链接拦截", suite.testImportRejectsExternalSymlink),
            ("损坏游戏库保留原数据", suite.testMalformedLibraryNeverOverwrittenByLoad),
            ("INI 注释保留与重复键处理", suite.testSettingsRespectCaseCommentsAndDeduplicateKeys),
            ("UTF-16 文件保护", suite.testUTF16INIRejectedRatherThanCorrupted),
            ("中文、空格与 shell 字符参数传递", suite.testProcessArgumentsPreserveChineseSpacesAndShellMetacharacters),
            ("Wine prefix 隔离与 WoW64 环境", suite.testPerGameWineEnvironmentIsIsolatedAndModernWoW64)
        ]
        var failures = 0
        for (name, check) in checks {
            do {
                try suite.setUpWithError(); try check(); try suite.tearDownWithError()
                print("PASS  \(name)")
            } catch {
                failures += 1; try? suite.tearDownWithError()
                print("FAIL  \(name): \(error)")
            }
        }
        print("\n\(checks.count - failures)/\(checks.count) 项检查通过。测试仅使用临时结构文件，不代表原版游戏已实测。")
        if failures != 0 { exit(1) }
    }
}
