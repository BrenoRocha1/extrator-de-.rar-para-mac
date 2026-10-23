import AppKit

// Desenha a logo do app: caixa de arquivo com zíper e uma seta saindo dela,
// sobre o amarelo das pastas do Explorador de Arquivos do Windows.
// Uso: swift MakeIcon.swift <pasta .iconset> [logo.png]
let out = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func drawLogo(in ctx: CGContext, size s: CGFloat) {
    // Tudo é desenhado numa grade de 1024 e depois escalado.
    ctx.saveGState()
    ctx.scaleBy(x: s / 1024, y: s / 1024)
    let space = CGColorSpaceCreateDeviceRGB()

    // Fundo: "squircle" do macOS com sombra
    let bg = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bgPath = CGPath(roundedRect: bg, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.35))
    ctx.addPath(bgPath); ctx.setFillColor(color(0xE09A00)); ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(bgPath); ctx.clip()
    let bgGradient = CGGradient(colorsSpace: space, colors: [color(0xFFDD70), color(0xFFC83D), color(0xF2A600)] as CFArray,
                                locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(bgGradient, start: CGPoint(x: 200, y: 924), end: CGPoint(x: 824, y: 100), options: [])
    // brilho suave no topo
    let glow = CGGradient(colorsSpace: space, colors: [color(0xFFFFFF, 0.28), color(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 360, y: 880), startRadius: 0,
                           endCenter: CGPoint(x: 360, y: 880), endRadius: 520, options: [])
    ctx.restoreGState()

    // Caixa (corpo)
    let body = CGRect(x: 262, y: 232, width: 500, height: 390)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 64, cornerHeight: 64, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: color(0x6B4400, 0.4))
    ctx.addPath(bodyPath); ctx.setFillColor(color(0xFFFFFF)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(bodyPath); ctx.clip()
    let bodyGradient = CGGradient(colorsSpace: space, colors: [color(0xFFFFFF), color(0xFFF1CC)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bodyGradient, start: CGPoint(x: 0, y: 622), end: CGPoint(x: 0, y: 232), options: [])
    ctx.restoreGState()

    // Tampa
    let lid = CGRect(x: 236, y: 576, width: 552, height: 104)
    let lidPath = CGPath(roundedRect: lid, cornerWidth: 40, cornerHeight: 40, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 18, color: color(0x6B4400, 0.3))
    ctx.addPath(lidPath); ctx.setFillColor(color(0xFFF8E6)); ctx.fillPath()
    ctx.restoreGState()

    // Zíper: dentes alternados descendo pelo meio da caixa
    ctx.setFillColor(color(0xD08A00))
    let toothW: CGFloat = 34, toothH: CGFloat = 22, gap: CGFloat = 12
    var y: CGFloat = 548
    var left = true
    while y > 340 {
        let x: CGFloat = left ? 512 - toothW : 512
        ctx.addPath(CGPath(roundedRect: CGRect(x: x, y: y - toothH, width: toothW, height: toothH),
                           cornerWidth: 6, cornerHeight: 6, transform: nil))
        ctx.fillPath()
        y -= toothH + gap / 2
        left.toggle()
    }
    // puxador do zíper
    let pull = CGPath(roundedRect: CGRect(x: 486, y: 252, width: 52, height: 64), cornerWidth: 16, cornerHeight: 16, transform: nil)
    ctx.addPath(pull); ctx.setFillColor(color(0x8A5A00)); ctx.fillPath()
    ctx.addPath(CGPath(roundedRect: CGRect(x: 502, y: 266, width: 20, height: 24), cornerWidth: 6, cornerHeight: 6, transform: nil))
    ctx.setFillColor(color(0xFFF1CC)); ctx.fillPath()

    // Seta saindo da caixa (extração)
    let arrow = CGMutablePath()
    arrow.move(to: CGPoint(x: 512, y: 868))      // ponta
    arrow.addLine(to: CGPoint(x: 622, y: 758))
    arrow.addLine(to: CGPoint(x: 552, y: 758))
    arrow.addLine(to: CGPoint(x: 552, y: 650))
    arrow.addLine(to: CGPoint(x: 472, y: 650))
    arrow.addLine(to: CGPoint(x: 472, y: 758))
    arrow.addLine(to: CGPoint(x: 402, y: 758))
    arrow.closeSubpath()
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: color(0x3D2B00, 0.35))
    ctx.setLineJoin(.round)
    ctx.addPath(arrow); ctx.setFillColor(color(0x5C3B00)); ctx.fillPath()
    ctx.restoreGState()
    ctx.addPath(arrow); ctx.clip()
    let arrowGradient = CGGradient(colorsSpace: space, colors: [color(0x7A5000), color(0x4A3000)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(arrowGradient, start: CGPoint(x: 0, y: 868), end: CGPoint(x: 0, y: 650), options: [])

    ctx.restoreGState()
}

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    drawLogo(in: context.cgContext, size: CGFloat(px))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try render(base).write(to: out.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(base * 2).write(to: out.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}

// Logo grande para o README
if CommandLine.arguments.count > 2 {
    try render(512).write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
}
