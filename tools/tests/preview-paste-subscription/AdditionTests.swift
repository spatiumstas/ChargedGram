__UNIQUE__

enum NSSound {
    static var beeps = 0
    static func beep() { beeps += 1 }
}
final class AdditionController {
    let pendingActions = PreviewSenderPendingActions()
    var sent = false
    var _urls = [URL(fileURLWithPath: "/existing")]
    var urls: [URL] {
        get { _urls }
        set {
__NORMALIZE__
        }
    }
    var insertAdditionUrls: (([URL]) -> Void)?
    let scrollAfterTransition = Atomic(value: false)
    init() {
        let scrollAfterTransition = self.scrollAfterTransition
__INSERT__
    }
}

final class AdditionTests: XCTestCase {
    override func setUp() { NSSound.beeps = 0 }
    func testDuplicateAdditionKeepsPendingAction() {
        for _ in 0..<2 {
            let controller = AdditionController()
            let action = controller.pendingActions.capture()
            controller.insertAdditionUrls?(controller.urls + controller.urls)
            XCTAssertEqual(controller.urls.count, 1)
            XCTAssertFalse(controller.scrollAfterTransition.with { $0 })
            XCTAssertTrue(action())
        }
        XCTAssertEqual(NSSound.beeps, 2)
    }
    func testMixedNewAndDuplicateSelectionRemainsAcceptedAddition() {
        for _ in 0..<2 {
            let controller = AdditionController()
            let action = controller.pendingActions.capture()
            let new = URL(fileURLWithPath: "/new")
            controller.insertAdditionUrls?(controller.urls + [new, new])
            XCTAssertEqual(controller.urls.map(\.path), ["/existing", "/new"])
            XCTAssertTrue(controller.scrollAfterTransition.with { $0 })
            XCTAssertFalse(action())
        }
        XCTAssertEqual(NSSound.beeps, 0)
    }
    func testEmptyAdditionDoesNotMutateFiles() {
        let controller = AdditionController()
        controller.insertAdditionUrls?([])
        controller.insertAdditionUrls?([])
        controller.insertAdditionUrls?(controller.urls)
        XCTAssertEqual(controller.urls.count, 1)
    }
    func testClosedCommittedAndReleasedPreviewDoNotObserveOrMutate() {
        for committed in [false, true] {
            let controller = AdditionController()
            if committed { controller.sent = true } else { controller.pendingActions.close() }
            controller.insertAdditionUrls?(controller.urls)
            controller.insertAdditionUrls?([URL(fileURLWithPath: "/new")])
            XCTAssertEqual(controller.urls.count, 1)
        }
        var controller: AdditionController? = AdditionController()
        weak var weakController = controller
        let action = controller?.insertAdditionUrls
        controller = nil
        XCTAssertNil(weakController)
        action?([URL(fileURLWithPath: "/new")])
        XCTAssertEqual(NSSound.beeps, 0)
    }
    func testAdditionAndDuplicateFeedback() {
        let controller = AdditionController()
        controller.insertAdditionUrls?(controller.urls)
        controller.insertAdditionUrls?([URL(fileURLWithPath: "/new")])
        XCTAssertEqual(NSSound.beeps, 1)
        XCTAssertEqual(controller.urls.count, 2)
    }
}
