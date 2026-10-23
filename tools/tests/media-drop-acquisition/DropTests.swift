import Foundation
import XCTest

__ACTION__

final class Disposable { func set(_ value: Disposable?) {} }
struct Signal<Value> {
    let subscribe: (@escaping (Value) -> Void) -> Void
    func start(next: @escaping (Value) -> Void) -> Disposable { subscribe(next); return Disposable() }
}
infix operator |> : AdditionPrecedence
func |> <A, B>(value: A, transform: (A) -> B) -> B { transform(value) }
func mapToSignal<A, B>(_ transform: @escaping (A) -> Signal<B>) -> (Signal<A>) -> Signal<B> {
    { source in Signal { next in _ = source.start(next: { _ = transform($0).start(next: next) }) } }
}
func deliverOnMainQueue<A>(_ signal: Signal<A>) -> Signal<A> { signal }
var pendingImages: [(String) -> Void] = []
func putToTemp(image: NSImage) -> Signal<String> { Signal { pendingImages.append($0) } }
final class NSPasteboard {
    enum Kind { case kFilenames, tiff }
    var types: [Kind]?
    var files: [String]?
    var imageData: Data?
    init(files: [String]? = nil, image: Bool = false) {
        self.files = files
        types = image ? [.tiff] : [.kFilenames]
        imageData = image ? Data([1]) : nil
    }
    func propertyList(forType: Kind) -> Any? { files }
    func data(forType: Kind) -> Data? { imageData }
}
final class NSImage { init?(data: Data) {} }
final class Window {}
var modalVisible = false
func hasModals(_ window: Window) -> Bool { modalVisible }
struct Event {
    struct Flags: OptionSet { let rawValue: Int; static let shift = Flags(rawValue: 1) }
    var modifierFlags: Flags = []
}
final class Application {
    var currentEvent: Event? = Event()
    var activations = 0
    func activate(ignoringOtherApps: Bool) { activations += 1 }
}
let NSApp = Application()
struct Labels {
    let chatDropEditTitle = "edit", chatDropEditDesc = "replace"
    let chatDropTitle = "send", chatDropQuickDesc = "media"
    let chatDropFolderTitle = "folder", chatDropFolderDesc = "archive"
    let chatDropAsFilesDesc = "files"
}
func strings() -> Labels { Labels() }
struct DragItem { let title: String; let desc: String; let handler: () -> Void }
let mediaExts = ["jpg", "png"]
extension String {
    var isDirectory: Bool { false }
    var nsstring: NSString { self as NSString }
}
var sizes: [String: Int64] = [:]
func fileSize(_ path: String) -> Int64? { sizes[path] }
func fileSizeLimitExceed(context: AccountContext, fileSize: Int64) -> Bool { fileSize <= 100 }
struct AccountContext { let account = 0 }
struct PeerId { let namespace = 0 }
enum Namespaces { enum Peer { static let SecretChat = 1 } }
enum Entry { case dropTarget }
enum Mode: Equatable { case media, file }
enum Via { case dragDrop }
struct EditState { let canEditMedia = true; var message = Message() }
struct Message { var id = 1 }
struct InterfaceState { var editState: EditState? }
struct Presentation {
    enum State { case normal, block }
    var state: State = .normal
    var interfaceState = InterfaceState()
}
struct MediaSenderContainer {
    let path: String
    var caption = ""
    let isFile: Bool
}
enum Sender {
    static func generateMedia(for container: MediaSenderContainer, account: Int, isSecretRelated: Bool) -> Signal<(Int, Int)> {
        Signal { $0((1, 0)) }
    }
}
final class ChatInteraction {
    let interactionContext = AccountContext()
    let peerId = PeerId()
    var presentation = Presentation()
    var revision = 0
    var admitted = true
    var previews: [[String]] = []
    var sends: [[String]] = []
    var replacements = 0
    func captureDeferredSendAction() -> ChatDeferredSendAction {
        let captured = revision
        return ChatDeferredSendAction { [weak self] in self?.revision == captured }
    }
    func showPreviewSender(_ files: [URL], _ media: Bool, _ caption: String?) {
        previews.append(files.map(\.path))
    }
    func sendMedia(_ files: [MediaSenderContainer]) {
        sends.append(files.map(\.path))
    }
    func beginMediaReplacement() -> Int { 0 }
    func applyMediaReplacement(_ media: Int, request: Int) { replacements += 1 }
}
final class ChatController {
    let context = AccountContext()
    var window: Window? = Window()
    let chatInteraction = ChatInteraction()
    var editingSessionId = 0
    let editCurrentMessagePhotoDisposable = Disposable()
    let updateMediaDisposable = Disposable()
__DROP__
}

final class DropTests: XCTestCase {
    override func setUp() {
        sizes = ["/photo.jpg": 10, "/file.txt": 10, "/large.jpg": 101]
        pendingImages = []
        modalVisible = false
        NSApp.currentEvent = Event()
        NSApp.activations = 0
    }
    func testHoverAndEntirelyRejectedSelectionCreateNoTask() {
        let controller = ChatController()
        let accepted = controller.draggingItems(for: NSPasteboard(files: ["/photo.jpg", "/large.jpg"]))
        XCTAssertEqual(accepted.count, 2)
        XCTAssertTrue(controller.draggingItems(for: NSPasteboard(files: ["/large.jpg", "/missing"])).isEmpty)
        XCTAssertEqual(NSApp.activations, 0)
    }
    func testPartialFilteringIsRecordedForBothPreviewModes() {
        for index in 0...1 {
            let controller = ChatController()
            controller.draggingItems(for: NSPasteboard(files: ["/photo.jpg", "/large.jpg"]))[index].handler()
            let chat = controller.chatInteraction
            XCTAssertEqual(chat.previews, [["/photo.jpg"]])
        }
    }
    func testUnavailableAndOversizedFilesAreFiltered() {
        for rejected in [["/missing"], ["/large.jpg", "/missing"], ["/missing", "/large.jpg"]] {
            let controller = ChatController()
            controller.draggingItems(for: NSPasteboard(files: ["/photo.jpg"] + rejected))[0].handler()
            XCTAssertEqual(controller.chatInteraction.previews, [["/photo.jpg"]])
        }
    }
    func testShiftDropKeepsBlockerAndAcceptedCountWithoutPreview() {
        let controller = ChatController()
        NSApp.currentEvent = Event(modifierFlags: .shift)
        controller.draggingItems(for: NSPasteboard(files: ["/photo.jpg", "/large.jpg"]))[0].handler()
        let chat = controller.chatInteraction
        XCTAssertEqual(chat.sends, [["/photo.jpg"]])
        XCTAssertTrue(chat.previews.isEmpty)
    }
    func testOneDropCanConsumeOnlyOneTargetOnce() {
        let controller = ChatController()
        let targets = controller.draggingItems(for: NSPasteboard(files: ["/photo.jpg"]))
        targets[0].handler(); targets[0].handler(); targets[1].handler()
        XCTAssertEqual(controller.chatInteraction.previews.count, 1)
        XCTAssertEqual(NSApp.activations, 1)
    }
    func testChangedComposerRejectsEveryOldTargetBeforeStartingTask() {
        for image in [false, true] {
            let controller = ChatController()
            let targets = controller.draggingItems(for: NSPasteboard(files: ["/photo.jpg"], image: image))
            controller.chatInteraction.revision += 1
            for item in targets { item.handler() }
            XCTAssertTrue(controller.chatInteraction.previews.isEmpty)
            XCTAssertTrue(pendingImages.isEmpty)
        }
        XCTAssertEqual(NSApp.activations, 0)
    }
    func testImagePreparationRetainsOriginalContextAndConsumesResultOnce() {
        for index in 0...1 {
            let controller = ChatController()
            let targets = controller.draggingItems(for: NSPasteboard(image: true))
            targets[index].handler()
            XCTAssertTrue(controller.chatInteraction.previews.isEmpty)

            pendingImages.last?("/prepared.jpg")
            pendingImages.last?("/duplicate.jpg")
            XCTAssertEqual(controller.chatInteraction.previews, [["/prepared.jpg"]])
        }
    }
    func testChangedComposerDuringImagePreparationDiscardsTask() {
        for index in 0...1 {
            let controller = ChatController()
            controller.draggingItems(for: NSPasteboard(image: true))[index].handler()
            controller.chatInteraction.revision += 1
            pendingImages.last?("/stale.jpg")
            XCTAssertTrue(controller.chatInteraction.previews.isEmpty)
        }
    }
    func testControllerDestructionDuringPreparationDiscardsJourney() {
        var controller: ChatController? = ChatController()
        controller?.draggingItems(for: NSPasteboard(image: true))[0].handler()
        weak var weakController = controller
        controller = nil
        XCTAssertNil(weakController)
        pendingImages.last?("/orphan.jpg")
    }
    func testEditingDropIsOneUseAndDoesNotStartComposeTask() {
        for image in [false, true] {
            let controller = ChatController()
            controller.chatInteraction.presentation.interfaceState.editState = EditState()
            let item = controller.draggingItems(for: NSPasteboard(files: ["/photo.jpg"], image: image))[0]
            item.handler(); item.handler()
            if image { pendingImages.last?("/prepared.jpg") }
            XCTAssertEqual(controller.chatInteraction.replacements, 1)
        }
    }
    func testChangedEditSessionRejectsOldTarget() {
        let controller = ChatController()
        controller.chatInteraction.presentation.interfaceState.editState = EditState()
        let item = controller.draggingItems(for: NSPasteboard(files: ["/photo.jpg"]))[0]
        controller.editingSessionId += 1
        item.handler()
        XCTAssertEqual(controller.chatInteraction.replacements, 0)
    }
    func testNoAnalyticsStillPreviewsAndSendsAndRejectsStaleActions() {
        for shift in [false, true] {
            let controller = ChatController()
            controller.chatInteraction.admitted = false
            NSApp.currentEvent = Event(modifierFlags: shift ? .shift : [])
            controller.draggingItems(for: NSPasteboard(files: ["/photo.jpg", "/large.jpg"]))[0].handler()
            XCTAssertEqual(controller.chatInteraction.previews.count, shift ? 0 : 1)
            XCTAssertEqual(controller.chatInteraction.sends.count, shift ? 1 : 0)
            let old = controller.draggingItems(for: NSPasteboard(files: ["/photo.jpg"]))
            controller.chatInteraction.revision += 1
            old[0].handler()
            XCTAssertEqual(controller.chatInteraction.previews.count + controller.chatInteraction.sends.count, 1)
        }
    }
    func testModalAndBlockedFileStateOfferNoTargets() {
        let controller = ChatController()
        modalVisible = true
        XCTAssertTrue(controller.draggingItems(for: NSPasteboard(image: true)).isEmpty)
        modalVisible = false
        controller.chatInteraction.presentation.state = .block
        XCTAssertTrue(controller.draggingItems(for: NSPasteboard(files: ["/photo.jpg"])).isEmpty)
        XCTAssertTrue(controller.draggingItems(for: NSPasteboard(image: true)).isEmpty)
    }
}
