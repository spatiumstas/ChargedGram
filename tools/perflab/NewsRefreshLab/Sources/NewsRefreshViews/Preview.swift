import AppKit
import TGUIKit
import ColorPalette

public func writeNewsRefreshPreviews(directory: String, iconFile: String) throws {
    initializeNewsRefreshLab()
    NSApp.setActivationPolicy(.accessory)
    let initialTheme = presentation
    updateTheme(PresentationTheme(colors: nightAccentPalette, search: initialTheme.search, inputTheme: initialTheme.inputTheme))
    let pixels = try Data(contentsOf: URL(fileURLWithPath: iconFile))
    let provider = CGDataProvider(data: pixels as CFData)!
    LottiePlayerView.previewImage = CGImage(width: 240, height: 240, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 960, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue), provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
    try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
    for gap in [CGFloat(2), 5, 9, 18] {
        let window = NSWindow(contentRect: NSMakeRect(0, 0, 360, 300), styleMask: [.borderless], backing: .buffered, defer: false)
        let list = NewsListView(frame: NSMakeRect(0, 0, 360, 300))
        list.backgroundColor = NSColor(srgbRed: 0.09, green: 0.14, blue: 0.18, alpha: 1)
        window.contentView = list
        list.topInset = 56
        let header = NSTextField(labelWithString: "For You                         Added")
        header.textColor = .white
        header.font = .systemFont(ofSize: 15, weight: .medium)
        header.frame = NSMakeRect(70, 18, 260, 24)
        list.addSubview(header)
        for row in 0..<3 {
            let text = NSTextField(wrappingLabelWithString: "News channel                                      3h\nThe latest stories from your subscriptions.\nA new update is available in the feed.")
            text.textColor = .white
            text.font = .systemFont(ofSize: 14)
            text.frame = NSMakeRect(18, 65 + CGFloat(row) * 78, 324, 68)
            list.addSubview(text)
        }
        let drop = NewsRefreshDropView(frame: .zero)
        list.setRefreshOverlay(drop)
        drop.showPull(NewsRefreshPresentation(gap: gap))
        window.orderFront(nil)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.08))
        list.layoutSubtreeIfNeeded()
        list.displayIfNeeded()
        let bitmap = list.bitmapImageRepForCachingDisplay(in: list.bounds)!
        list.cacheDisplay(in: list.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: directory).appendingPathComponent("pull-\(Int(gap)).png"))
        window.orderOut(nil)
        withExtendedLifetime(window) {}
    }
}
