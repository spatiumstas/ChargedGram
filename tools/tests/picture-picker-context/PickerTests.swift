import Cocoa
import XCTest

final class Window { var appearance: NSAppearance? }
struct Theme { let appearance: NSAppearance? = nil }
let theme = Theme()
final class App {
    func window(withWindowNumber: Int) -> Window? { nil }
}
let NSApp = App()
let IKPictureTakerShowEffectsKey = "effects"
let IKPictureTakerOutputImageMaxSizeKey = "size"
fileprivate final class IKPictureTaker: NSObject {
    static let shared = IKPictureTaker()
    var delegates: [PickerObserver] = []
    var image: NSImage?
    let windowNumber = 0
    static func pictureTaker() -> IKPictureTaker { shared }
    override func setValue(_ value: Any?, forKey key: String) {}
    func outputImage() -> NSImage? { image }
    func beginSheet(for window: Window, withDelegate delegate: PickerObserver, didEnd: Selector, contextInfo: Any?) {
        delegates.append(delegate)
    }
}
extension NSSize {
    func aspectFilled(_ target: NSSize) -> NSSize { target }
}
extension NSImage {
    func precomposed() -> CGImage {
        generateImage(NSMakeSize(1, 1), contextGenerator: { _, _ in })!
    }
}
func generateImage(_ size: NSSize, contextGenerator: (NSSize, CGContext) -> Void) -> CGImage? {
    let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    contextGenerator(size, context)
    return context.makeImage()
}
__PICKER__

final class PickerTests: XCTestCase {
    override func setUp() {
        activePicturePicker = nil
        IKPictureTaker.shared.delegates = []
        IKPictureTaker.shared.image = nil
    }
    override func tearDown() { activePicturePicker = nil }
    private func complete(_ index: Int = 0, code: NSApplication.ModalResponse = .OK) {
        let taker = IKPictureTaker.shared
        taker.delegates[index].validated(taker, code.rawValue, nil)
    }
    func testOverlappingRequestCannotReplaceOriginalOwner() {
        for _ in 0..<2 {
            var originals = 0
            var denied = 0
            let index = IKPictureTaker.shared.delegates.count
            pickImage(for: Window()) { _ in
                originals += 1
            }
            pickImage(for: Window()) { image in
                denied += 1
                XCTAssertNil(image)
            }
            XCTAssertEqual(denied, 1)
            XCTAssertEqual(originals, 0)
            XCTAssertEqual(IKPictureTaker.shared.delegates.count, index + 1)
            complete(index)
            XCTAssertEqual(originals, 1)
            XCTAssertNil(activePicturePicker)
        }
    }
    func testDuplicateResultDoesNotCallAgain() {
        var callbacks = 0
        pickImage(for: Window()) { _ in callbacks += 1 }
        complete()
        complete(code: .cancel)
        XCTAssertEqual(callbacks, 1)
    }
    func testCompletionCanOpenNextPickerAndOldCallbackCannotResolveIt() {
        var deliveredSecond = 0
        pickImage(for: Window()) { _ in
            pickImage(for: Window()) { _ in deliveredSecond += 1 }
        }
        complete()
        XCTAssertEqual(IKPictureTaker.shared.delegates.count, 2)
        complete()
        XCTAssertEqual(deliveredSecond, 0)
        complete(1)
        XCTAssertEqual(deliveredSecond, 1)
    }
    func testCancelledUnknownAndMissingOutputRemainNil() {
        for code in [NSApplication.ModalResponse.cancel, .abort, .OK] {
            var calls = 0
            let index = IKPictureTaker.shared.delegates.count
            pickImage(for: Window()) { image in calls += 1; XCTAssertNil(image) }
            complete(index, code: code)
            XCTAssertEqual(calls, 1)
        }
    }
    func testAcceptedImageIsDeliveredOnlyToOriginalRequest() {
        IKPictureTaker.shared.image = NSImage(size: NSMakeSize(1, 1))
        var delivered: NSImage?
        pickImage(for: Window()) { delivered = $0 }
        complete()
        XCTAssertNotNil(delivered)
    }

}
