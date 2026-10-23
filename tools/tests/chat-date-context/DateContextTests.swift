import Foundation
import XCTest

public typealias PeerId = Int64
protocol AccountContextProtocol {}
struct AccountContext: AccountContextProtocol {}
final class TextViewLayout {}
final class ModalViewController {}
struct ChatNavigationHooks {
    static var shared = ChatNavigationHooks()
    var makeDateSelector: (any AccountContextProtocol, Date?, Int32?, ChatDateSelectorMode, @escaping (Date, Int32?) -> Void, TextViewLayout?) -> ModalViewController = { _, _, _, _, _, _ in ModalViewController() }
}

__DATE_MODE__
__DATE_HELPER__

final class DateContextTests: XCTestCase {
    override func tearDown() {
        ChatNavigationHooks.shared = ChatNavigationHooks()
        super.tearDown()
    }

    func testConstructionAndSynchronousSelectionPreserveValues() {
        var deliveries = 0
        ChatNavigationHooks.shared.makeDateSelector = { _, _, _, _, selected, _ in
            selected(Date(timeIntervalSince1970: 100), 10)
            return ModalViewController()
        }
        let controller = chatDateSelector(context: AccountContext(), mode: .schedule(7), selectedAt: { date, repeatPeriod in
            XCTAssertEqual(date.timeIntervalSince1970, 100)
            XCTAssertEqual(repeatPeriod, 10)
            deliveries += 1
        })
        XCTAssertEqual(deliveries, 1)
    }

    func testDelayedSelectionWorksAfterControllerDestruction() throws {
        var selected: ((Date, Int32?) -> Void)?
        ChatNavigationHooks.shared.makeDateSelector = { _, _, _, _, callback, _ in
            selected = callback
            return ModalViewController()
        }
        var deliveries = 0
        var controller: ModalViewController? = chatDateSelector(context: AccountContext(), mode: .schedule(7), selectedAt: { _, _ in
            deliveries += 1
        })
        controller = nil
        try XCTUnwrap(selected)(Date(), nil)
        XCTAssertEqual(deliveries, 1)
    }

    func testDateActionPreservesReentrantSelection() throws {
        var capturedMode: ChatDateSelectorMode?
        var selected: ((Date, Int32?) -> Void)?
        ChatNavigationHooks.shared.makeDateSelector = { _, _, _, mode, callback, _ in
            capturedMode = mode
            selected = callback
            return ModalViewController()
        }
        var actions = 0
        var deliveries = 0
        _ = chatDateSelector(context: AccountContext(), mode: .dateAction(title: "Publish", done: { _ in "Confirm" }, action: .init(string: "Now", callback: {
            actions += 1
            selected?(Date(), nil)
        })), selectedAt: { _, _ in
            deliveries += 1
        })
        guard case let .dateAction(title, done, action) = try XCTUnwrap(capturedMode) else {
            return XCTFail("Date action was not preserved")
        }
        XCTAssertEqual(title, "Publish")
        XCTAssertEqual(done(Date()), "Confirm")
        XCTAssertEqual(action.string, "Now")
        action.callback()
        XCTAssertEqual(actions, 1)
        XCTAssertEqual(deliveries, 1)
    }

    func testFactoryArgumentsArePreserved() {
        let date = Date(timeIntervalSince1970: 123)
        let info = TextViewLayout()
        ChatNavigationHooks.shared.makeDateSelector = { _, defaultDate, repeatPeriod, mode, _, infoText in
            XCTAssertEqual(defaultDate, date)
            XCTAssertEqual(repeatPeriod, 45)
            XCTAssertTrue(infoText === info)
            guard case .schedule(9) = mode else {
                XCTFail("Schedule peer was not preserved")
                return ModalViewController()
            }
            return ModalViewController()
        }
        let controller = chatDateSelector(context: AccountContext(), defaultDate: date, repeatPeriod: 45, mode: .schedule(9), selectedAt: { _, _ in }, infoText: info)
    }
}

private final class MessageEngine {
    var scheduleTime: Int32?
    var accepts = true
    var calls = 0
    func outgoingMessageWithChatContextResult(to: Int64, threadId: Int64?, botId: Int64, result: Int, replyToMessageId: Int64?, replyToStoryId: Int?, hideVia: Bool, silentPosting: Bool, scheduleTime: Int32?, sendPaidMessageStars: Int?, postpone: Bool, correlationId: Int64?) -> Int? {
        self.scheduleTime = scheduleTime
        calls += 1
        return accepts ? result : nil
    }
}
private struct Engine {
    let messages = MessageEngine()
}
private struct SendingContext {
    let account = 1
    let engine = Engine()
}
private final class Transition {
    var calls = 0
    func set(handler: () -> Void) { calls += 1 }
}
private final class ChatController {
    let chatInteraction = 0
    let nextTransaction = Transition()
}

private struct InlineSignal<Value> {
    let value: Value
    func start(next: (Value) -> Void) { next(value) }
}
private func enqueueMessages(account: Int, peerId: Int64, messages: [Int]) -> InlineSignal<[Int?]> {
    InlineSignal(value: messages.map { Optional($0) })
}
private struct InlineSendFixture {
    let context = SendingContext()
    let controller = ChatController()
    let results = (botId: Int64(1), count: 1)
    let result = 7
    let afterSentTransition: () -> Void = {}
    func makePeerId() -> Int64 { 2 }
    func threadId64() -> Int64? { nil }
    func takeReplyId() -> Int64? { nil }
    func takePaidMessageStars() -> Int? { nil }
    func send(atDate: Int32?) {
__INLINE_APPLY__
        apply(controller, atDate: atDate)
    }
}

final class InlineSchedulingTests: XCTestCase {
    func testSelectedDateReachesEnqueue() {
        let fixture = InlineSendFixture()
        fixture.send(atDate: 1_800_000_000)
        XCTAssertEqual(fixture.context.engine.messages.scheduleTime, 1_800_000_000)
        XCTAssertEqual(fixture.context.engine.messages.calls, 1)
        XCTAssertEqual(fixture.controller.nextTransaction.calls, 1)
    }

    func testImmediateSendHasNoScheduleTime() {
        let fixture = InlineSendFixture()
        fixture.send(atDate: nil)
        XCTAssertNil(fixture.context.engine.messages.scheduleTime)
        XCTAssertEqual(fixture.context.engine.messages.calls, 1)
    }

    func testRejectedResultDoesNotSetSendTransition() {
        let fixture = InlineSendFixture()
        fixture.context.engine.messages.accepts = false
        fixture.send(atDate: 1_800_000_000)
        XCTAssertEqual(fixture.context.engine.messages.calls, 1)
        XCTAssertEqual(fixture.context.engine.messages.scheduleTime, 1_800_000_000)
        XCTAssertEqual(fixture.controller.nextTransaction.calls, 0)
    }
}
