import Foundation
import RedAlertCore

final class CoreTests {
    var temp: URL!
    func setUpWithError() throws {
        temp = FileManager.default.temporaryDirectory.appendingPathComponent("redalert-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
    }
    func tearDownWithError() throws { try FileManager.default.removeItem(at: temp) }

    func fixture(at path: String = "游戏 原版", yuri: Bool = false) throws -> URL {
        let directory = temp.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Structural PE fixture, never used to claim a real game launch.
        var pe = Data(repeating: 0, count: 128)
        pe[0] = 0x4d; pe[1] = 0x5a; pe[60] = 64; pe[64] = 0x50; pe[65] = 0x45
        try pe.write(to: directory.appendingPathComponent("Game.EXE"))
        for name in ["RA2.MIX", "Language.mix"] { try Data("fixture".utf8).write(to: directory.appendingPathComponent(name)) }
        if yuri {
            try pe.write(to: directory.appendingPathComponent("gamemd.exe"))
            for name in ["ra2md.mix", "langmd.mix"] { try Data("fixture".utf8).write(to: directory.appendingPathComponent(name)) }
        }
        return directory
    }

    func testMixedCaseDirectorySupportsBothVersions() throws {
        let item = try unwrap(GameImporter.inspect(fixture(yuri: true)))
        try checkEqual(item.recommendedExecutable(for: .redAlert2), "Game.EXE")
        try checkEqual(item.recommendedExecutable(for: .yurisRevenge), "gamemd.exe")
        try checkEqual(item.detectedKinds, [.redAlert2, .yurisRevenge])
        try checkTrue(item.missingFiles(for: .yurisRevenge).isEmpty)
    }

    func testYuriRequiresExpansionAssets() throws {
        let item = try unwrap(GameImporter.inspect(fixture()))
        try checkEqual(item.missingFiles(for: .yurisRevenge), ["ra2md.mix", "langmd.mix"])
    }

    func testFindsGameInsideExtractedWrapper() throws {
        let source = try fixture(at: "下载/解压/RA2")
        let results = try GameImporter.discover(in: temp.appendingPathComponent("下载"))
        try checkEqual(results.map { $0.directory.resolvingSymlinksInPath().path }, [source.resolvingSymlinksInPath().path])
    }

    func testRejectsCorruptExecutableBeforeImport() throws {
        let source = try fixture()
        try Data("not a Windows executable".utf8).write(to: source.appendingPathComponent("Game.EXE"))
        let item = try unwrap(GameImporter.inspect(source))
        let paths = AppPaths(root: temp.appendingPathComponent("library"))
        try expectThrows(try GameImporter.importGame(inspection: item, name: "RA2", kind: .redAlert2,
            executable: "Game.EXE", usesYuri: false, paths: paths))
        try checkFalse(FileManager.default.fileExists(atPath: paths.games.path))
    }

    func testImportIsolationPersistenceConfigurationAndRestore() throws {
        let source = try fixture(yuri: true)
        let originalINI = Data([59, 32, 0xd6, 0xd0, 0xce, 0xc4, 13, 10]) + Data("[Video]\r\nScreenWidth=800\r\nScreenHeight=600\r\n[Audio]\r\nMusicVolume=0.4\r\n".utf8)
        try originalINI.write(to: source.appendingPathComponent("RA2.INI"))
        let item = try unwrap(GameImporter.inspect(source))
        let paths = AppPaths(root: temp.appendingPathComponent("library"))
        let profile = try GameImporter.importGame(inspection: item, name: "原版", kind: .redAlert2,
            executable: "Game.EXE", usesYuri: false, paths: paths)
        let second = try GameImporter.importGame(inspection: item, name: "尤里", kind: .yurisRevenge,
            executable: "gamemd.exe", usesYuri: true, paths: paths)
        var state = LibraryState(); state.profiles = [profile, second]
        let store = LibraryStore(paths: paths); try store.save(state)
        try checkEqual(try store.load().profiles, [profile, second])
        let compatibility = temp.appendingPathComponent("compatibility")
        try FileManager.default.createDirectory(at: compatibility, withIntermediateDirectories: true)
        try Data("fixture patch dll".utf8).write(to: compatibility.appendingPathComponent("ddraw.dll"))
        try Data("[ddraw]\nrenderer=auto\n[game]\ntshack=true\n".utf8).write(to: compatibility.appendingPathComponent("ddraw.ini"))
        try GameConfiguration.prepare(profile: profile, paths: paths, compatibility: compatibility)
        let drawSettings = try String(contentsOf: paths.game(profile.id).appendingPathComponent("ddraw.ini"), encoding: .utf8)
        try checkTrue(drawSettings.contains("windowed=true"))
        try checkTrue(drawSettings.contains("fullscreen=true"))
        try checkTrue(drawSettings.contains("width=0"))
        try checkTrue(drawSettings.contains("height=0"))
        try checkTrue(drawSettings.contains("toggle_borderless=true"))
        let modifiedINI = try Data(contentsOf: paths.game(profile.id).appendingPathComponent("RA2.INI"))
        try checkTrue(modifiedINI.starts(with: originalINI.prefix(10)))
        try checkTrue(String(decoding: modifiedINI, as: UTF8.self).contains("ScreenWidth=1280"))
        try checkTrue(String(decoding: modifiedINI, as: UTF8.self).contains("MusicVolume=0.4"))
        try checkEqual(try Data(contentsOf: source.appendingPathComponent("RA2.INI")), originalINI)
        try checkEqual(try Data(contentsOf: paths.game(second.id).appendingPathComponent("RA2.INI")), originalINI)
        // Repeated launches must preserve the very first backup.
        try GameConfiguration.prepare(profile: profile, paths: paths, compatibility: compatibility)
        try GameConfiguration.restore(profile: profile, paths: paths)
        try checkEqual(try Data(contentsOf: paths.game(profile.id).appendingPathComponent("RA2.INI")), originalINI)
        try checkFalse(FileManager.default.fileExists(atPath: paths.game(profile.id).appendingPathComponent("ddraw.dll").path))
        try checkFalse(FileManager.default.fileExists(atPath: paths.game(profile.id).appendingPathComponent("ddraw.ini").path))
    }

    func testImportRejectsExternalSymlink() throws {
        let source = try fixture()
        try FileManager.default.createSymbolicLink(atPath: source.appendingPathComponent("save-link").path, withDestinationPath: "/tmp")
        let item = try unwrap(GameImporter.inspect(source))
        try expectThrows(try GameImporter.importGame(inspection: item, name: "RA2", kind: .redAlert2,
            executable: "Game.EXE", usesYuri: false, paths: AppPaths(root: temp.appendingPathComponent("library"))))
    }

    func testMalformedLibraryNeverOverwrittenByLoad() throws {
        let paths = AppPaths(root: temp.appendingPathComponent("library")); try paths.prepare()
        let broken = Data("{broken user library".utf8); try broken.write(to: paths.library)
        try expectThrows(try LibraryStore(paths: paths).load())
        try checkEqual(try Data(contentsOf: paths.library), broken)
    }

    func testSettingsRespectCaseCommentsAndDeduplicateKeys() throws {
        let input = Data("; preserve\r\n[video]\r\nscreenwidth=800\r\nScreenWidth=640\r\nOther=1\r\n[Audio]\r\nMusic=1\r\n".utf8)
        let output = try INIEditor.patch(input, sections: ["Video": ["ScreenWidth": "1280", "ScreenHeight": "720"]])
        let text = String(decoding: output, as: UTF8.self)
        try checkEqual(text.components(separatedBy: "ScreenWidth=").count, 2)
        try checkTrue(text.contains("Other=1\r\n")); try checkTrue(text.contains("[Audio]\r\nMusic=1\r\n"))
        try checkTrue(text.contains("ScreenHeight=720"))
    }

    func testUTF16INIRejectedRatherThanCorrupted() throws {
        try expectThrows(try INIEditor.patch(Data([0xff, 0xfe, 65, 0]), sections: ["Video": ["ScreenWidth": "1280"]]))
    }

    func testProcessArgumentsPreserveChineseSpacesAndShellMetacharacters() throws {
        let output = temp.appendingPathComponent("stdout.log")
        let argument = "中文 MOD ' $(touch SHOULD_NOT_EXIST) ; `echo nope`"
        try checkEqual(try Commands.run(URL(fileURLWithPath: "/usr/bin/printf"), ["%s", argument], log: output), 0)
        try checkEqual(try String(contentsOf: output, encoding: .utf8), argument)
    }

    func testPerGameWineEnvironmentIsIsolatedAndModernWoW64() throws {
        let runtime = WineRuntime(executable: URL(fileURLWithPath: "/tmp/wine/bin/wine"), name: "test")
        let prefix = temp.appendingPathComponent("独立 prefix")
        let environment = RuntimeManager.environment(runtime: runtime, prefix: prefix, useDDraw: true)
        try checkEqual(environment["WINEPREFIX"], prefix.path)
        try checkNil(environment["WINEARCH"])
        try checkEqual(environment["WINEDLLOVERRIDES"], "ddraw=n,b;winemenubuilder.exe=d")
    }
}
