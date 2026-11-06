import Foundation

public struct LibraryStore {
    public let paths: AppPaths
    public init(paths: AppPaths) { self.paths = paths }
    public func load() throws -> LibraryState {
        try paths.prepare()
        guard FileManager.default.fileExists(atPath: paths.library.path) else { return LibraryState() }
        let state = try JSONDecoder().decode(LibraryState.self, from: Data(contentsOf: paths.library))
        guard state.schemaVersion == 1 else { throw RedAlertError.message("游戏库版本过新，请更新客户端。") }
        return state
    }
    public func save(_ state: LibraryState) throws {
        try paths.prepare()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: paths.library, options: .atomic)
    }
}
