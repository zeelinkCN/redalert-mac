import Foundation

public enum GameKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case redAlert2, yurisRevenge, republic, custom
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .redAlert2: return "红色警戒 2"
        case .yurisRevenge: return "尤里的复仇"
        case .republic: return "共和国之辉"
        case .custom: return "自定义 MOD"
        }
    }
    public var subtitle: String {
        switch self {
        case .redAlert2: return "RED ALERT 2"
        case .yurisRevenge: return "YURI’S REVENGE"
        case .republic: return "GLORY OF THE REPUBLIC"
        case .custom: return "YOUR NEXT BATTLEFIELD"
        }
    }
    public var detail: String {
        switch self {
        case .redAlert2: return "盟军与苏军重返战场。原版引擎与简体中文，熟悉的基地、坦克与钢铁洪流。"
        case .yurisRevenge: return "第三势力加入战场。独立管理尤里资料片，与原版并存。"
        case .republic: return "熟悉的中国阵营，记忆中的共和国之辉。经典 MOD 独立部署，随时重返战场。"
        case .custom: return "为其他 RA2 / 尤里 MOD 建立独立档案，自选启动程序与参数。"
        }
    }
    public var executableCandidates: [String] {
        switch self {
        case .yurisRevenge: return ["gamemd.exe", "yuri.exe", "ra2md.exe", "yuri's revenge.exe"]
        case .custom: return ["gamemd.exe", "game.exe", "ra2.exe", "yuri.exe", "syringe.exe", "red alert 2.exe", "yuri's revenge.exe"]
        default: return ["game.exe", "ra2.exe", "red alert 2.exe"]
        }
    }
}

public enum DisplayMode: String, Codable, CaseIterable, Sendable {
    case windowed, borderless, fullscreen
    public var title: String {
        switch self {
        case .windowed: return "窗口模式"
        case .borderless: return "无边框全屏"
        case .fullscreen: return "全屏模式"
        }
    }
}

public struct GameProfile: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var kind: GameKind
    public var executable: String
    public var arguments: [String]
    public var importedAt: Date
    public var lastPlayed: Date?
    public var playSeconds: Double
    public var displayMode: DisplayMode
    public var width: Int
    public var height: Int
    public var renderer: String
    public var useCompatibilityPatch: Bool
    public var usesYuri: Bool
    /// nil in older libraries also means automatic sizing.
    public var followsDisplay: Bool?

    public init(id: UUID = UUID(), name: String, kind: GameKind, executable: String,
                arguments: [String] = [], usesYuri: Bool = false) {
        self.id = id; self.name = name; self.kind = kind; self.executable = executable
        self.arguments = arguments; importedAt = Date(); playSeconds = 0
        displayMode = .borderless; width = 1280; height = 720
        renderer = "gdi"; useCompatibilityPatch = true
        self.usesYuri = kind == .yurisRevenge || usesYuri
        followsDisplay = true
    }
}

public struct LibraryState: Codable, Sendable {
    public var schemaVersion = 1
    public var profiles: [GameProfile] = []
    public var customWinePath: String?
    public init() {}
}

public struct AppPaths: Sendable {
    public let root: URL
    public init(root: URL? = nil) {
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RedAlertMac", isDirectory: true)
    }
    public var library: URL { root.appendingPathComponent("library.json") }
    public var games: URL { root.appendingPathComponent("Games", isDirectory: true) }
    public var runtimes: URL { root.appendingPathComponent("Runtimes", isDirectory: true) }
    public var logs: URL { root.appendingPathComponent("Logs", isDirectory: true) }
    public func game(_ id: UUID) -> URL { games.appendingPathComponent(id.uuidString, isDirectory: true) }
    public func prefix(_ id: UUID) -> URL { root.appendingPathComponent("Prefixes/\(id.uuidString)", isDirectory: true) }
    public func prepare() throws {
        for directory in [root, games, runtimes, logs, root.appendingPathComponent("Prefixes")] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}

public enum RedAlertError: LocalizedError {
    case message(String)
    public var errorDescription: String? { if case .message(let s) = self { return s }; return nil }
}
