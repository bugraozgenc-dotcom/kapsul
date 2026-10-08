import AppKit

let output = CommandLine.arguments[1]
let preview = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : nil
let width: CGFloat = 760, height: CGFloat = 500
func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect { NSRect(x: x, y: height-y-h, width: w, height: h) }
func color(_ hex: Int, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255)/255, green: CGFloat((hex >> 8) & 255)/255, blue: CGFloat(hex & 255)/255, alpha: alpha)
}
func text(_ value: String, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ font: NSFont, _ ink: NSColor, center: Bool = false) {
    let paragraph = NSMutableParagraphStyle(); paragraph.alignment = center ? .center : .left
    (value as NSString).draw(in: rect(x,y,w,70), withAttributes: [.font: font, .foregroundColor: ink, .paragraphStyle: paragraph])
}
func render(_ withIcons: Bool) -> NSBitmapImageRep {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1520, pixelsHigh: 1000, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    bitmap.size = NSSize(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!; NSGraphicsContext.current = context
    NSGradient(colors: [color(0xF8FAFF),color(0xEDF0FC),color(0xE9EFFE)])!.draw(in: NSRect(x:0,y:0,width:width,height:height), angle: -65)
    for (box, ink) in [(rect(-100,130,480,480),color(0xAFC9FF,0.35)), (rect(435,-130,490,490),color(0xD7C6FF,0.4))] {
        NSGradient(starting: ink, ending: ink.withAlphaComponent(0))!.draw(in: NSBezierPath(ovalIn: box), relativeCenterPosition: .zero)
    }
    let brand = NSImage(contentsOfFile: "Sources/CopyGlass/Resources/app-icon.png")!
    brand.draw(in: rect(42,35,42,42))
    text("Kapsül",96,35,360,.systemFont(ofSize:32,weight:.bold),color(0x17284B))
    text("Kopyaladığın her şey, bir arada.",44,91,600,.systemFont(ofSize:16,weight:.regular),color(0x64728D))
    text("KURULUM",602,49,114,.systemFont(ofSize:10,weight:.semibold),color(0x7180A0),center:true)
    for x: CGFloat in [115,455] {
        let card = NSBezierPath(roundedRect: rect(x,172,190,196), xRadius:28,yRadius:28)
        NSGraphicsContext.saveGraphicsState()
        let shadow=NSShadow(); shadow.shadowColor=color(0x536FB0,0.12);shadow.shadowBlurRadius=20;shadow.shadowOffset=NSSize(width:0,height:-8);shadow.set()
        color(0xFFFFFF,0.62).setFill();card.fill();NSGraphicsContext.restoreGraphicsState()
        color(0xFFFFFF,0.9).setStroke();card.lineWidth=1.5;card.stroke()
    }
    let path=NSBezierPath(); path.move(to:NSPoint(x:350,y:height-254));path.line(to:NSPoint(x:407,y:height-254))
    path.move(to:NSPoint(x:396,y:height-243));path.line(to:NSPoint(x:407,y:height-254));path.line(to:NSPoint(x:396,y:height-265))
    color(0x6B83BF).setStroke();path.lineWidth=3;path.lineCapStyle = .round;path.lineJoinStyle = .round;path.stroke()
    let pill=NSBezierPath(roundedRect:rect(109,413,542,47),xRadius:23.5,yRadius:23.5)
    color(0xFFFFFF,0.6).setFill();pill.fill()
    text("Kapsül’ü Uygulamalar klasörüne sürükle.",119,427,522,.systemFont(ofSize:15,weight:.medium),color(0x334B79),center:true)
    text("Drag Kapsül to Applications to install.",130,474,500,.systemFont(ofSize:11),color(0x7C88A1),center:true)
    if withIcons {
        brand.draw(in:rect(146,191,128,128))
        NSWorkspace.shared.icon(forFile:"/Applications").draw(in:rect(486,191,128,128))
        text("Kapsül",130,333,160,.systemFont(ofSize:14),color(0x263A62),center:true)
        text("Applications",470,333,160,.systemFont(ofSize:14),color(0x263A62),center:true)
    }
    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}
try render(false).representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:output))
if let preview { try render(true).representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:preview)) }
