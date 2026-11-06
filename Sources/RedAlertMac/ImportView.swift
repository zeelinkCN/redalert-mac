import SwiftUI
import RedAlertCore

struct ImportView: View {
    @EnvironmentObject var model: AppModel
    @State private var directoryID = ""
    @State private var kind: GameKind = .redAlert2
    @State private var name = ""
    @State private var executable = ""
    @State private var usesYuri = false
    private var inspection: GameInspection? { model.inspections.first { $0.id == directoryID } ?? model.inspections.first }
    private var missing: [String] { inspection?.missingFiles(for: kind, usesYuri: usesYuri) ?? [] }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 9) {
                Text("IMPORT MISSION").font(.system(size: 9, design: .monospaced)).tracking(2).foregroundStyle(Theme.red)
                Text("导入作战版本").font(.system(size: 24, weight: .bold))
                Text("游戏会复制到客户端游戏库，原目录会保留。").font(.system(size: 12)).foregroundStyle(Theme.secondary)
            }
            if let inspection {
                Form {
                    if model.inspections.count > 1 {
                        Picker("游戏目录", selection: $directoryID) {
                            ForEach(model.inspections) { Text($0.directory.lastPathComponent).tag($0.id) }
                        }.onChange(of: directoryID) { _ in updateSelection() }
                    }
                    Text(inspection.directory.path).font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.secondary).textSelection(.enabled)
                    Picker("版本类型", selection: $kind) {
                        ForEach(GameKind.allCases) { Text($0.title).tag($0) }
                    }.onChange(of: kind) { _ in updateSelection() }
                    TextField("版本名称", text: $name)
                    Picker("启动程序", selection: $executable) {
                        if inspection.executables.isEmpty { Text("未找到 EXE").tag("") }
                        ForEach(inspection.executables, id: \.self) { Text($0).tag($0) }
                    }
                    if kind == .custom { Toggle("这个 MOD 基于尤里的复仇", isOn: $usesYuri) }
                }.formStyle(.grouped).scrollDisabled(true)
                if !missing.isEmpty {
                    Label("缺少 \(missing.joined(separator: "、"))，请选择完整安装目录。", systemImage: "exclamationmark.triangle")
                        .font(.system(size: 12)).foregroundStyle(Theme.gold)
                } else {
                    Label("基础资源已识别；实际战役、音乐和 MOD 完整性以游戏运行为准。", systemImage: "checkmark.circle")
                        .font(.system(size: 11)).foregroundStyle(Theme.green)
                }
                if kind == .republic {
                    Text("共和国之辉必须已安装在这个目录中。选择此类型仅用于版本管理，不会自动将原版转换为 MOD。")
                        .font(.system(size: 11)).foregroundStyle(Theme.secondary).lineSpacing(4)
                }
            }
            HStack {
                Text("各版本的配置和存档独立保存。").font(.system(size: 10)).foregroundStyle(Theme.secondary)
                Spacer()
                Button("取消") { model.showImport = false }.keyboardShortcut(.cancelAction)
                Button("确认导入") {
                    if let inspection { model.importGame(inspection: inspection, name: name, kind: kind, executable: executable, usesYuri: usesYuri) }
                }.buttonStyle(.borderedProminent).tint(Theme.red).keyboardShortcut(.defaultAction)
                    .disabled(executable.isEmpty || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !missing.isEmpty)
            }
        }.padding(28).frame(width: 620).background(Theme.panel)
            .onAppear {
                directoryID = model.inspections.first?.id ?? ""
                if let inspection, inspection.recommendedExecutable(for: model.selectedKind) != nil { kind = model.selectedKind }
                else { kind = inspection?.detectedKinds.first ?? .custom }
                updateSelection()
            }
    }
    private func updateSelection() {
        guard let inspection else { return }
        executable = inspection.recommendedExecutable(for: kind) ?? inspection.executables.first ?? ""
        name = kind == .custom ? inspection.directory.lastPathComponent : kind.title
        usesYuri = kind == .yurisRevenge || (kind == .custom && inspection.hasYuri)
    }
}

struct ProfileSettingsView: View {
    @EnvironmentObject var model: AppModel
    @State var profile: GameProfile
    @State private var argumentText = ""
    @State private var executables: [String] = []
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("版本设置").font(.system(size: 23, weight: .bold)); Spacer(); Tag(text: profile.kind.title, color: profile.kind.color) }
            Form {
                Section("启动") {
                    TextField("版本名称", text: $profile.name)
                    Picker("启动程序", selection: $profile.executable) { ForEach(executables, id: \.self) { Text($0).tag($0) } }
                    if profile.kind == .custom { Toggle("基于尤里的复仇", isOn: $profile.usesYuri) }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("启动参数（每行一个参数，无需引号）").font(.system(size: 11)).foregroundStyle(Theme.secondary)
                        TextEditor(text: $argumentText).font(.system(size: 11, design: .monospaced)).frame(height: 48)
                    }
                }
                Section("显示兼容") {
                    Toggle("使用内置 cnc-ddraw 补丁", isOn: $profile.useCompatibilityPatch)
                    Picker("显示模式", selection: $profile.displayMode) { ForEach(DisplayMode.allCases, id: \.self) { Text($0.title).tag($0) } }.disabled(!profile.useCompatibilityPatch)
                    Toggle("分辨率跟随当前显示器", isOn: Binding(get: { profile.followsDisplay != false }, set: { profile.followsDisplay = $0 }))
                        .disabled(!profile.useCompatibilityPatch)
                    HStack {
                        Text("分辨率"); Spacer()
                        TextField("宽", value: $profile.width, format: .number.grouping(.never)).frame(width: 85)
                        Text("×").foregroundStyle(Theme.secondary)
                        TextField("高", value: $profile.height, format: .number.grouping(.never)).frame(width: 85)
                    }.disabled(!profile.useCompatibilityPatch || profile.followsDisplay != false)
                    Picker("渲染器", selection: $profile.renderer) {
                        Text("GDI（推荐）").tag("gdi"); Text("自动").tag("auto"); Text("OpenGL（取决于 Wine 构建）").tag("opengl")
                    }.disabled(!profile.useCompatibilityPatch)
                    Text("关闭补丁前，可先还原客户端首次调整前的显示文件。较新的 macOS Wine 构建不含 OpenGL，建议保留 GDI。")
                        .font(.system(size: 10)).foregroundStyle(Theme.secondary)
                    Text("Ctrl + Tab 释放鼠标 · Option + Enter 切换窗口 / 全屏 · Command + Tab 切换应用")
                        .font(.system(size: 10)).foregroundStyle(Theme.gold)
                    Button("还原原始显示文件") {
                        do { try GameConfiguration.restore(profile: profile, paths: model.paths); profile.useCompatibilityPatch = false }
                        catch { model.error = error.localizedDescription }
                    }
                }
                Section("文件与存档") {
                    Button("打开此版本的游戏目录") { model.revealGame(profile) }
                    Button("移除此版本…", role: .destructive) { model.editingProfile = nil; model.remove(profile) }
                }
            }.formStyle(.grouped)
            HStack {
                Text("设置仅应用于此游戏副本。").font(.system(size: 10)).foregroundStyle(Theme.secondary)
                Spacer()
                Button("取消") { model.editingProfile = nil }.keyboardShortcut(.cancelAction)
                Button("保存") {
                    profile.arguments = argumentText.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
                    model.update(profile)
                }.buttonStyle(.borderedProminent).tint(Theme.red).keyboardShortcut(.defaultAction)
                    .disabled(profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(25).frame(width: 630, height: 670).background(Theme.panel)
            .onAppear {
                executables = (try? GameImporter.inspect(model.paths.game(profile.id)))?.executables ?? [profile.executable]
                argumentText = profile.arguments.joined(separator: "\n")
            }
    }
}
