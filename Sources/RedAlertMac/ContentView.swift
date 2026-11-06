import SwiftUI
import AppKit
import RedAlertCore

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 206)
            Rectangle().fill(Theme.line).frame(width: 1)
            VStack(spacing: 0) {
                topbar
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        switch model.page {
                        case .library: library
                        case .environment: EnvironmentView()
                        case .guide: GuideView()
                        }
                    }.padding(28).frame(maxWidth: 1320, alignment: .leading)
                }
                footer
            }
        }
        .background(Theme.background)
        .foregroundStyle(Color(hex: 0xECECE7))
        .overlay(alignment: .bottom) {
            if let notice = model.notice {
                HStack { Image(systemName: "checkmark.circle").foregroundStyle(Theme.green); Text(notice).font(.system(size: 12));
                    Button { model.notice = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
                }.padding(14).background(Theme.panel, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line)).padding(.bottom, 54).padding(.horizontal, 24)
            }
        }
        .overlay {
            if let busy = model.busy {
                Color.black.opacity(0.55).ignoresSafeArea()
                VStack(spacing: 18) {
                    ProgressView().controlSize(.large)
                    Text(busy).font(.system(size: 14)).multilineTextAlignment(.center)
                    Text("完成后会自动返回，请保持客户端打开。").font(.system(size: 12)).foregroundStyle(Theme.secondary)
                }.padding(36).frame(width: 430).background(Theme.panel, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .alert("需要处理", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("知道了", role: .cancel) { model.error = nil }
            if model.logURL != nil { Button("查看启动日志") { model.error = nil; model.openLog() } }
        } message: { Text(model.error ?? "") }
        .sheet(isPresented: $model.showImport) { ImportView().environmentObject(model) }
        .sheet(item: $model.editingProfile) { profile in ProfileSettingsView(profile: profile).environmentObject(model) }
        .sheet(isPresented: $model.showLog) { LogView().environmentObject(model) }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in model.refreshEnvironment() }
        .onAppear { model.prepareOnFirstAppearance() }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Theme.red.opacity(0.12)).frame(width: 36, height: 39)
                    Image(systemName: "star.circle.fill").font(.system(size: 25)).foregroundStyle(Theme.red)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("红警作战中心").font(.system(size: 15, weight: .bold))
                    Text("RED ALERT · MAC").font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(1.4).foregroundStyle(Theme.secondary)
                }
            }.padding(.top, 45).padding(.bottom, 37).padding(.horizontal, 22)
            Text("作战指挥").font(.system(size: 10, weight: .medium)).foregroundStyle(Theme.secondary).padding(.horizontal, 24).padding(.bottom, 12)
            ForEach(Page.allCases, id: \.self) { page in
                Button { model.page = page } label: {
                    HStack(spacing: 12) {
                        Image(systemName: page.icon).frame(width: 17)
                        Text(page.rawValue).font(.system(size: 13, weight: model.page == page ? .semibold : .regular))
                        Spacer()
                        if page == .environment && (model.runtime == nil || !model.rosettaReady) { Circle().fill(Theme.gold).frame(width: 5, height: 5) }
                    }.foregroundStyle(model.page == page ? Color.white : Theme.secondary)
                        .padding(.horizontal, 14).frame(height: 42)
                        .background(model.page == page ? Color.white.opacity(0.055) : .clear, in: RoundedRectangle(cornerRadius: 7))
                        .overlay(alignment: .leading) { if model.page == page { RoundedRectangle(cornerRadius: 1).fill(Theme.red).frame(width: 2, height: 17) } }
                }.buttonStyle(.plain).padding(.horizontal, 12).padding(.bottom, 5)
            }
            Rectangle().fill(Theme.line).frame(height: 1).padding(.horizontal, 24).padding(.vertical, 24)
            HStack { Text("我的版本"); Spacer(); Text(String(model.state.profiles.count)).monospacedDigit() }
                .font(.system(size: 10, weight: .medium)).foregroundStyle(Theme.secondary).padding(.horizontal, 24).padding(.bottom, 12)
            ForEach(GameKind.allCases) { kind in
                Button { model.select(kind) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: kind.symbol).font(.system(size: 11)).foregroundStyle(kind.color.opacity(0.85)).frame(width: 17)
                        Text(kind.title).font(.system(size: 12))
                        Spacer()
                        if model.state.profiles.contains(where: { $0.kind == kind }) { Circle().fill(Theme.green).frame(width: 4, height: 4) }
                    }.foregroundStyle(model.selectedKind == kind && model.page == .library ? Color.white : Theme.secondary)
                        .padding(.horizontal, 26).frame(height: 37).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
            Spacer(minLength: 25)
            HStack(spacing: 10) {
                RadarScreen().frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) { Circle().fill(model.runtime != nil && model.rosettaReady ? Theme.green : Theme.gold).frame(width: 5, height: 5)
                    Text(model.runtime != nil && model.rosettaReady ? "兼容组件已就绪" : "兼容组件自动准备中").font(.system(size: 11)) }
                Text("原版引擎 · 本地运行").font(.system(size: 9)).foregroundStyle(Theme.secondary)
                }
            }.padding(15).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 8)).padding(16)
            Text("COMMAND CENTER  /  v0.1.0").font(.system(size: 8, design: .monospaced)).foregroundStyle(Theme.secondary.opacity(0.6))
                .padding(.horizontal, 24).padding(.bottom, 22)
        }.background(Theme.sidebar)
    }

    private var topbar: some View {
        HStack(spacing: 9) {
            Text("指挥中心").foregroundStyle(Theme.secondary)
            Image(systemName: "chevron.right").font(.system(size: 8)).foregroundStyle(Theme.secondary.opacity(0.5))
            Text(model.page.rawValue)
            Spacer()
            Text(RuntimeManager.isAppleSilicon ? "APPLE SILICON" : "INTEL MAC").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1).foregroundStyle(Theme.secondary)
            Rectangle().fill(Theme.line).frame(width: 1, height: 14).padding(.horizontal, 8)
            Image(systemName: "internaldrive").foregroundStyle(Theme.green)
            Text("本地客户端").foregroundStyle(Theme.secondary)
        }.font(.system(size: 11)).padding(.horizontal, 32).frame(height: 59)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }

    private var library: some View {
        Group {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("COMMAND UPLINK / 指挥链路已连接").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(2).foregroundStyle(Theme.red)
                    Text("指挥官，欢迎归队。").font(.system(size: 26, weight: .bold))
                    Text("经典战场，重返你的 Mac。").font(.system(size: 12)).foregroundStyle(Theme.secondary)
                }
                Spacer()
                ActionButton(title: "导入游戏", icon: "plus", primary: false) { model.chooseImport() }
            }
            hero
            VStack(alignment: .leading, spacing: 14) {
                HStack { Text("选择作战版本").font(.system(size: 15, weight: .semibold)); Spacer()
                    Text("原版与 MOD 独立管理").font(.system(size: 10)).foregroundStyle(Theme.secondary) }
                HStack(spacing: 14) {
                    ForEach([GameKind.redAlert2, .yurisRevenge, .republic]) { kind in versionCard(kind) }
                }
            }
            deployment
        }
    }

    private var hero: some View {
        ZStack(alignment: .leading) {
            GeometryReader { geometry in
                CommandArtwork(kind: model.selectedKind).frame(width: geometry.size.width, height: geometry.size.height).clipped()
            }
            LinearGradient(stops: [.init(color: .black.opacity(0.75), location: 0), .init(color: .black.opacity(0.5), location: 0.4), .init(color: .clear, location: 0.75)], startPoint: .leading, endPoint: .trailing)
            LinearGradient(colors: [.clear, .black.opacity(0.4)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 15) {
                HStack(spacing: 8) { Rectangle().fill(model.selectedKind.color).frame(width: 18, height: 2)
                    Text("OPERATION \(model.selectedKind.number) / 经典战场").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.6).foregroundStyle(model.selectedKind.color) }
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.selectedKind.title).font(.system(size: 38, weight: .black)).tracking(1).shadow(color: .black.opacity(0.7), radius: 10)
                    Text(model.selectedKind.subtitle).font(.system(size: 12, weight: .medium, design: .monospaced)).tracking(3).foregroundStyle(Theme.secondary)
                }
                Text(model.selectedKind.detail).font(.system(size: 12)).lineSpacing(5).foregroundStyle(Color.white.opacity(0.6)).frame(maxWidth: 350, alignment: .leading)
                HStack(spacing: 12) {
                    if model.selectedProfile != nil {
                        ActionButton(title: model.runningID == nil ? "开始作战" : "游戏运行中", icon: "play.fill") { model.launch() }
                            .disabled(model.runningID != nil)
                    } else {
                        ActionButton(title: model.selectedKind == .custom ? "导入 MOD" : "下载并部署", icon: "arrow.down") { model.deployDefault(model.selectedKind) }
                    }
                    Tag(text: "原版引擎 · 全屏适配", color: Theme.gold)
                }
            }.padding(28)
            VStack { HStack { Spacer(); Tag(text: "原版引擎 / LOCAL", color: Theme.gold) }; Spacer()
                HStack { Spacer(); Text("战术背景 · 原创概念图").font(.system(size: 8, design: .monospaced)).foregroundStyle(Color.white.opacity(0.45)) }
            }.padding(20)
        }.frame(height: 266).clipShape(CutPanel(cut: 13))
            .overlay(CutPanel(cut: 13).stroke(model.selectedKind.color.opacity(0.45)))
            .overlay(alignment: .bottomLeading) { Rectangle().fill(model.selectedKind.color).frame(width: 80, height: 2).padding(.leading, 13) }
    }

    private func versionCard(_ kind: GameKind) -> some View {
        let count = model.state.profiles.filter { $0.kind == kind }.count
        let selected = model.selectedKind == kind
        return Button { model.select(kind) } label: {
            VStack(alignment: .leading, spacing: 13) {
                HStack { Image(systemName: kind.symbol).font(.system(size: 19)).foregroundStyle(kind.color)
                    Spacer(); Text(kind.number).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.secondary.opacity(0.5)) }
                VStack(alignment: .leading, spacing: 6) {
                    Text(kind.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.white)
                    Text(kind.subtitle).font(.system(size: 8, design: .monospaced)).tracking(0.6).foregroundStyle(Theme.secondary)
                }
                HStack(spacing: 5) {
                    Circle().fill(count > 0 ? Theme.green : Theme.secondary.opacity(0.5)).frame(width: 4, height: 4)
                    Text(count > 0 ? "已导入 \(count) 个版本" : "等待导入").font(.system(size: 10)).foregroundStyle(count > 0 ? Theme.green : Theme.secondary)
                    Spacer(); Image(systemName: selected ? "checkmark.circle.fill" : "arrow.up.right").foregroundStyle(selected ? kind.color : Theme.secondary).font(.system(size: 12))
                }
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    ZStack(alignment: .trailing) {
                        Theme.panel
                        Image(systemName: kind.symbol).font(.system(size: 85, weight: .black)).foregroundStyle(kind.color.opacity(selected ? 0.1 : 0.035)).offset(x: 10, y: 7)
                        LinearGradient(colors: [kind.color.opacity(selected ? 0.13 : 0.04), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                    }.clipShape(CutPanel(cut: 8))
                }
                .overlay(CutPanel(cut: 8).stroke(selected ? kind.color.opacity(0.65) : Theme.line))
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private var deployment: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack {
                Text("出发前的准备").font(.system(size: 15, weight: .semibold))
                Spacer()
                Button { model.openLog() } label: { Label("启动日志", systemImage: "terminal").font(.system(size: 11)).foregroundStyle(Theme.secondary) }.buttonStyle(.plain)
            }
            if let profile = model.selectedProfile {
                HStack(spacing: 14) {
                    Image(systemName: profile.kind.symbol).font(.system(size: 22)).foregroundStyle(profile.kind.color)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(profile.name).font(.system(size: 14, weight: .semibold))
                        Text("\(profile.executable)  ·  \(profile.followsDisplay != false ? "自适应分辨率" : "\(profile.width) × \(profile.height)")  ·  \(profile.displayMode.title)").font(.system(size: 10)).foregroundStyle(Theme.secondary)
                    }
                    Spacer()
                    Button { model.editingProfile = profile } label: { Image(systemName: "slider.horizontal.3").font(.system(size: 15)).frame(width: 32, height: 36) }
                        .buttonStyle(.plain).disabled(model.runningID == profile.id).help("版本设置")
                    if model.runningID == profile.id {
                        ActionButton(title: "退出游戏", icon: "stop.fill", primary: false) { model.stop() }
                    } else {
                        ActionButton(title: "启动游戏", icon: "play.fill") { model.launch() }
                            .disabled(model.runningID != nil)
                    }
                }
                let profiles = model.state.profiles.filter { $0.kind == model.selectedKind }
                if profiles.count > 1 {
                    Picker("当前档案", selection: Binding(get: { profile.id }, set: { model.selectedID = $0 })) {
                        ForEach(profiles) { Text($0.name).tag($0.id) }
                    }.font(.system(size: 11))
                }
                if model.runningID == profile.id {
                    HStack(spacing: 10) { ProgressView().controlSize(.small); Text(model.runMessage).font(.system(size: 11)).foregroundStyle(Theme.gold) }
                }
            } else {
                HStack(spacing: 17) {
                    Image(systemName: "folder.badge.plus").font(.system(size: 26, weight: .light)).foregroundStyle(Theme.secondary)
                    VStack(alignment: .leading, spacing: 7) {
                        Text("部署你的第一场战役").font(.system(size: 14, weight: .medium))
                        Text("导入已安装的 Windows 游戏目录，客户端会为它建立独立副本。").font(.system(size: 11)).foregroundStyle(Theme.secondary)
                    }
                    Spacer()
                    ActionButton(title: model.selectedKind == .custom ? "导入 MOD" : "自动部署", icon: "arrow.down") { model.deployDefault(model.selectedKind) }
                }
            }
            Rectangle().fill(Theme.line).frame(height: 1)
            HStack(spacing: 24) {
                preparationStep("01", "游戏已部署", done: model.selectedProfile != nil)
                preparationStep("02", "兼容组件自动就绪", done: model.runtime != nil && model.rosettaReady)
                preparationStep("03", "选择版本，即刻开战", done: false)
                Spacer(minLength: 0)
            }
        }.padding(21).background(Theme.panel, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))
    }

    private func preparationStep(_ number: String, _ title: String, done: Bool) -> some View {
        HStack(spacing: 8) {
            Text(done ? "✓" : number).font(.system(size: 9, design: .monospaced)).foregroundStyle(done ? Theme.green : Theme.secondary)
                .frame(width: 21, height: 21).background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))
            Text(title).font(.system(size: 10)).foregroundStyle(Theme.secondary)
        }
    }
    private var footer: some View {
        HStack(spacing: 7) {
            Image(systemName: "externaldrive").font(.system(size: 10))
            Text("Ctrl + Tab 释放鼠标  ·  Option + Enter 切换全屏")
            Spacer()
            Text("⌘ O  导入游戏").padding(.trailing, 14)
            Button { model.page = .guide } label: { Text("使用指南 ↗") }.buttonStyle(.plain)
        }.font(.system(size: 9)).foregroundStyle(Theme.secondary.opacity(0.8)).padding(.horizontal, 32).frame(height: 38)
            .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}
