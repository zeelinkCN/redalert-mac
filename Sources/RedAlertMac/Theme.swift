import SwiftUI
import RedAlertCore

enum Theme {
    static let background = Color(hex: 0x101214)
    static let sidebar = Color(hex: 0x141719)
    static let panel = Color(hex: 0x1B1D1B)
    static let line = Color(hex: 0xBDA17B).opacity(0.15)
    static let red = Color(hex: 0xF05043)
    static let secondary = Color(hex: 0x92999D)
    static let green = Color(hex: 0xA6BD94)
    static let gold = Color(hex: 0xD8B97B)
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
}
extension GameKind {
    var color: Color {
        switch self { case .redAlert2: return Theme.red; case .yurisRevenge: return Color(hex: 0xBA99DA)
        case .republic: return Theme.gold; case .custom: return Color(hex: 0x8DADBB) }
    }
    var symbol: String {
        switch self { case .redAlert2: return "star.fill"; case .yurisRevenge: return "eye.fill"
        case .republic: return "sun.max.fill"; case .custom: return "shippingbox.fill" }
    }
    var number: String {
        switch self { case .redAlert2: return "01"; case .yurisRevenge: return "02"; case .republic: return "03"; case .custom: return "04" }
    }
}

struct ActionButton: View {
    let title: String
    var icon: String = "arrow.right"
    var primary = true
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) { Image(systemName: icon); Text(title).fontWeight(.semibold) }
                .font(.system(size: 13)).padding(.horizontal, 18).frame(height: 40)
                .foregroundStyle(primary ? Color.white : Color.white.opacity(0.85))
                .background {
                    CutPanel(cut: 7).fill(LinearGradient(colors: primary ? [Color(hex: 0xDC4836), Color(hex: 0x8E211B)] : [Color.white.opacity(0.07), Color.white.opacity(0.025)], startPoint: .top, endPoint: .bottom))
                }
                .overlay(CutPanel(cut: 7).stroke(primary ? Theme.red.opacity(0.8) : Theme.line))
        }.buttonStyle(.plain)
    }
}

struct CutPanel: Shape {
    var cut: CGFloat = 10
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: .init(x: rect.minX + cut, y: rect.minY))
        p.addLines([.init(x: rect.maxX, y: rect.minY), .init(x: rect.maxX, y: rect.maxY-cut),
                    .init(x: rect.maxX-cut, y: rect.maxY), .init(x: rect.minX, y: rect.maxY), .init(x: rect.minX, y: rect.minY+cut)])
        p.closeSubpath(); return p
    }
}

struct CommandArtwork: View {
    var kind: GameKind = .redAlert2
    var body: some View {
        if let url = Bundle.module.url(forResource: "command-center", withExtension: "png", subdirectory: "Artwork"),
           let image = NSImage(contentsOf: url) {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                .saturation(kind == .yurisRevenge ? 0.08 : 0.8)
                .colorMultiply(kind == .yurisRevenge ? Color(hex: 0xB98BE5) : kind == .republic ? Color(hex: 0xEBC589) : .white)
        }
    }
}

struct RadarScreen: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.08, paused: reduceMotion)) { timeline in
            Canvas { ctx, size in
                let c = CGPoint(x: size.width/2, y: size.height/2), r = min(size.width, size.height)/2 - 3
                for factor in [CGFloat(0.33), CGFloat(0.66), CGFloat(1)] {
                    ctx.stroke(Path(ellipseIn: CGRect(x: c.x-r*factor, y: c.y-r*factor, width: r*2*factor, height: r*2*factor)), with: .color(Theme.green.opacity(0.22)), lineWidth: 0.6)
                }
                var axes = Path(); axes.move(to: .init(x: c.x-r, y: c.y)); axes.addLine(to: .init(x: c.x+r, y: c.y)); axes.move(to: .init(x: c.x, y: c.y-r)); axes.addLine(to: .init(x: c.x, y: c.y+r))
                ctx.stroke(axes, with: .color(Theme.green.opacity(0.18)), lineWidth: 0.6)
                let angle = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6) / 6 * .pi * 2
                for i in 0..<24 {
                    let a = angle - Double(i)*0.025
                    var ray = Path(); ray.move(to: c); ray.addLine(to: .init(x: c.x + cos(a)*r, y: c.y + sin(a)*r))
                    ctx.stroke(ray, with: .color(Theme.green.opacity(0.2 * (1-Double(i)/24))), lineWidth: 1.5)
                }
                for point in [CGPoint(x: c.x-r*0.3, y: c.y+r*0.45), .init(x: c.x+r*0.5, y: c.y-r*0.25)] {
                    ctx.fill(Path(CGRect(x: point.x, y: point.y, width: 2.5, height: 2.5)), with: .color(Theme.green.opacity(0.8)))
                }
            }
        }.accessibilityLabel("动态雷达装饰")
    }
}

struct Tag: View {
    let text: String
    var color: Color = Theme.secondary
    var body: some View {
        Text(text).font(.system(size: 10, weight: .medium)).tracking(0.4)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .foregroundStyle(color).background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 4))
    }
}

struct BattlefieldArt: View {
    let color: Color
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            var grid = Path()
            for x in stride(from: CGFloat(0), through: w, by: 32) { grid.move(to: .init(x: x, y: 0)); grid.addLine(to: .init(x: x, y: h)) }
            for y in stride(from: CGFloat(0), through: h, by: 32) { grid.move(to: .init(x: 0, y: y)); grid.addLine(to: .init(x: w, y: y)) }
            ctx.stroke(grid, with: .color(color.opacity(0.09)), lineWidth: 0.6)
            let center = CGPoint(x: w * 0.67, y: h * 0.52)
            for r in [CGFloat(68), CGFloat(110), CGFloat(150)] {
                let circle = Path(ellipseIn: .init(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
                ctx.stroke(circle, with: .color(color.opacity(0.16)), style: StrokeStyle(lineWidth: 1, dash: r == 110 ? [4, 7] : []))
            }
            var sweep = Path(); sweep.move(to: center); sweep.addLine(to: .init(x: center.x + 140, y: center.y - 80))
            ctx.stroke(sweep, with: .color(color.opacity(0.35)), lineWidth: 1)
            for i in 0..<12 {
                let x = w * 0.25 + CGFloat((i * 59) % 280)
                let y = CGFloat((i * 83) % 240)
                let block = CGRect(x: x, y: y, width: CGFloat(18 + i % 3 * 9), height: CGFloat(14 + i % 4 * 7))
                ctx.fill(Path(block), with: .color(Color.white.opacity(0.025)))
                ctx.stroke(Path(block), with: .color(color.opacity(0.12)), lineWidth: 1)
            }
            // Original vector illustration: a tank on a tactical plotting table.
            var tank = ctx
            tank.translateBy(x: center.x, y: center.y)
            tank.rotate(by: .degrees(-28))
            for x in [-CGFloat(40), CGFloat(26)] {
                let tread = Path(roundedRect: .init(x: x, y: -47, width: 14, height: 94), cornerRadius: 5)
                tank.fill(tread, with: .color(color.opacity(0.18))); tank.stroke(tread, with: .color(color.opacity(0.7)), lineWidth: 1)
                for y in stride(from: -CGFloat(38), through: 39, by: 9) {
                    var p = Path(); p.move(to: .init(x: x + 2, y: y)); p.addLine(to: .init(x: x + 12, y: y))
                    tank.stroke(p, with: .color(color.opacity(0.45)), lineWidth: 0.6)
                }
            }
            var hull = Path(); hull.move(to: .init(x: -26, y: -40)); hull.addLines([
                .init(x: 26, y: -40), .init(x: 32, y: -25), .init(x: 28, y: 38),
                .init(x: -28, y: 38), .init(x: -32, y: -25)]); hull.closeSubpath()
            tank.fill(hull, with: .color(Color(hex: 0x202626))); tank.stroke(hull, with: .color(color.opacity(0.85)), lineWidth: 1.3)
            let turret = Path(roundedRect: .init(x: -18, y: -19, width: 36, height: 43), cornerRadius: 9)
            tank.fill(turret, with: .color(color.opacity(0.14))); tank.stroke(turret, with: .color(color), lineWidth: 1)
            tank.fill(Path(CGRect(x: -4, y: -77, width: 8, height: 61)), with: .color(Color(hex: 0x27302C)))
            tank.stroke(Path(CGRect(x: -4, y: -77, width: 8, height: 61)), with: .color(color.opacity(0.9)), lineWidth: 1)
            tank.stroke(Path(ellipseIn: .init(x: -8, y: -4, width: 16, height: 16)), with: .color(color.opacity(0.7)), lineWidth: 1)
            for point in [CGPoint(x: center.x - 116, y: center.y + 55), CGPoint(x: center.x + 86, y: center.y - 71)] {
                ctx.fill(Path(ellipseIn: .init(x: point.x, y: point.y, width: 4, height: 4)), with: .color(color))
            }
            ctx.draw(Text("TACTICAL ARCHIVE / RA2").font(.system(size: 8, design: .monospaced)).foregroundColor(color.opacity(0.5)), at: .init(x: w * 0.67, y: h - 20))
        }
        .accessibilityLabel("坦克战术线稿")
    }
}
