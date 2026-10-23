import AppKit
import TGUIKit

private let labImages: [NSImage] = ["Icon_SearchField", "Icon_SearchClear", "Icon_Quote", "Icon_Quote_Collapse", "Icon_Quote_Expand", "Icon_CopyCode"].map { name in
    let image = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
        NSColor.black.setFill()
        rect.insetBy(dx: 4, dy: 4).fill()
        return true
    }
    image.setName(name)
    return image
}

func initializeNewsRefreshLab() {
    _ = NSApplication.shared
    _ = labImages
    System.updateScaleFactor(2)
    System.liquidGlass = false
}

var theme: PresentationTheme { presentation }
final class NewsShimmerView: View {}
struct LottieColor { let keyPath: String; let color: NSColor }
struct LottieAnimationEntryKey {
    enum Key { case bundle(String) }
    let key: Key
    let size: NSSize
    let backingScale: Int
    let colors: [LottieColor]
}
enum LottiePlayPolicy { case loopAt(firstStart: Int32, range: ClosedRange<Int32>), toEnd(from: Int32) }
struct LottieAnimation {
    let compressed: Data
    let key: LottieAnimationEntryKey
    let playPolicy: LottiePlayPolicy
    let colors: [LottieColor]
}
enum LocalAnimatedSticker: String {
    case news_drop
    var data: Data? { Data() }
}
final class LottiePlayerView: View {
    static var previewImage: CGImage?
    private(set) var animation: LottieAnimation?
    func set(_ animation: LottieAnimation?) {
        self.animation = animation
        if let animation = animation, let image = LottiePlayerView.previewImage {
            layer?.contents = NSImage(cgImage: image, size: NSMakeSize(240, 240)).precomposed(animation.colors.first?.color)
        } else {
            layer?.contents = nil
        }
        layer?.contentsGravity = .resizeAspect
    }
}

var labOffsets: [ObjectIdentifier: CGFloat] = [:]
func labLiveDocumentOffset(_ table: TableView) -> NSPoint {
    return NSMakePoint(0, labOffsets[ObjectIdentifier(table)] ?? table.liveDocumentOffset.y)
}
func labSetDocumentOffset(_ table: TableView, _ y: CGFloat) {
    labOffsets[ObjectIdentifier(table)] = y
}
