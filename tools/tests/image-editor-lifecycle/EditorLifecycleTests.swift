import Foundation
import XCTest
import SwiftSignalKit

public protocol AccountContextProtocol {}
struct AccountContext: AccountContextProtocol {}
public struct EditedImageData {}
public enum ModalAnimationCloseBehaviour { case common }
public enum KeyHandlerResult { case invoked, rejected }
class Controller {
    var closeCount = 0
    func close(animationType: ModalAnimationCloseBehaviour = .common) { closeCount += 1 }
    func escapeKeyAction() -> KeyHandlerResult { .rejected }
}
final class Editor: Controller {
    private let resultValue = Promise<(URL, EditedImageData?)>()
    private let closedDisposable = DisposableSet()
    var onClose: () -> Void = {}
    var onCancelled: (() -> Void)?
__EDITOR_CLOSE__
    func confirmLater(_ value: URL) -> () -> Void {
        let promise = Promise<(URL, EditedImageData?)>()
        promise.set(.single((value, nil)))
__EDITOR_CONFIRM__
        return invoke
    }
    func cancelControl() { cancelEditing() }
}
struct Hooks {
__EDITOR_HOOK__
}

final class EditorLifecycleTests: XCTestCase {
    private let url = URL(fileURLWithPath: "/fixture/image.png")

    func testCancelControlAndEscapeResolveCancellationAndCloseOnlyOnce() {
        for escapeFirst in [false, true] {
            let editor = Editor()
            var cancelled = 0
            var closed = 0
            var completed = 0
            editor.onCancelled = { cancelled += 1 }
            editor.onClose = { closed += 1 }
            let subscription = editor.result.start(completed: { completed += 1 })
            if escapeFirst { _ = editor.escapeKeyAction() } else { editor.cancelControl() }
            _ = editor.escapeKeyAction()
            editor.cancelControl()
            editor.close()
            XCTAssertEqual(cancelled, 1)
            XCTAssertEqual(closed, 1)
            XCTAssertEqual(editor.closeCount, 1)
            XCTAssertEqual(completed, 1)
            subscription.dispose()
        }
    }

    func testGenericCloseDoesNotInventCancellationOrAcceptLateConfirmation() {
        let editor = Editor()
        let confirm = editor.confirmLater(url)
        var cancelled = 0
        var values = 0
        editor.onCancelled = { cancelled += 1 }
        let subscription = editor.result.start(next: { _ in values += 1 })
        editor.close()
        confirm()
        editor.cancelControl()
        let lateSubscription = editor.result.start(next: { _ in values += 1 })
        XCTAssertEqual(cancelled, 0)
        XCTAssertEqual(values, 0)
        XCTAssertEqual(editor.closeCount, 1)
        subscription.dispose()
        lateSubscription.dispose()
    }

    func testExplicitCancellationPreventsDelayedConfirmationFromPublishing() {
        let editor = Editor()
        let confirm = editor.confirmLater(url)
        var cancelled = 0
        var values = 0
        editor.onCancelled = { cancelled += 1 }
        let subscription = editor.result.start(next: { _ in values += 1 })
        editor.cancelControl()
        confirm()
        confirm()
        let lateSubscription = editor.result.start(next: { _ in values += 1 })
        XCTAssertEqual(cancelled, 1)
        XCTAssertEqual(values, 0)
        subscription.dispose()
        lateSubscription.dispose()
    }

    func testAcceptedOutputCannotBeReclassifiedByReentrantCancelOrClose() {
        let editor = Editor()
        let confirm = editor.confirmLater(url)
        var values = 0
        var cancelled = 0
        editor.onCancelled = { cancelled += 1 }
        let subscription = editor.result.start(next: { _ in
            values += 1
            editor.cancelControl()
        })
        confirm()
        confirm()
        XCTAssertEqual(values, 1)
        XCTAssertEqual(cancelled, 0)
        XCTAssertEqual(editor.closeCount, 1)
        subscription.dispose()
    }

    func testHookForwardsExplicitCancellationOnceAfterDisposal() {
        var hooks = Hooks()
        var cancel: (() -> Void)?
        var dismiss: (() -> Void)?
        hooks.editImageWithEvents = { _, _, _, cancelled, dismissed in
            cancel = cancelled
            dismiss = dismissed
            return .never()
        }
        var cancellations = 0
        var dismissals = 0
        let subscription = hooks.editImageObserved(AccountContext(), url, nil, cancelled: {
            cancellations += 1
        }, dismissed: { dismissals += 1 }).start()
        subscription.dispose()
        cancel?()
        dismiss?()
        cancel?()
        XCTAssertEqual(cancellations, 1)
        XCTAssertEqual(dismissals, 0)
    }

    func testHookSuccessfulOutputWinsOverReentrantDismissalAndCompletion() {
        var hooks = Hooks()
        var dismiss: (() -> Void)?
        hooks.editImageWithEvents = { [url] _, _, _, _, dismissed in
            dismiss = dismissed
            return .single((url, nil))
        }
        var values = 0
        var dismissals = 0
        let subscription = hooks.editImageObserved(AccountContext(), url, nil, cancelled: { XCTFail("Accepted output cannot cancel") }, dismissed: { dismissals += 1 }).start(next: { _ in
            values += 1
            dismiss?()
        })
        subscription.dispose()
        dismiss?()
        XCTAssertEqual(values, 1)
        XCTAssertEqual(dismissals, 0)
    }

    func testHookConstructionFailureAndLegacyEmptyCompletionAreUnknownOnce() {
        for events in [false, true] {
            var hooks = Hooks()
            if events {
                hooks.editImageWithEvents = { _, _, _, _, dismissed in
                    dismissed()
                    return .complete()
                }
            } else {
                hooks.editImageWithContext = { _, _, _ in .complete() }
            }
            var dismissals = 0
            let subscription = hooks.editImageObserved(AccountContext(), url, nil, cancelled: { XCTFail("Unknown exit cannot cancel") }, dismissed: {
                dismissals += 1
            }).start()
            subscription.dispose()
            XCTAssertEqual(dismissals, 1)
        }
    }

    func testReentrantCancelClosesOnce() {
        let editor = Editor()
        editor.onCancelled = {
            editor.close()
        }
        let subscription = editor.result.start()
        editor.cancelControl()
        XCTAssertEqual(editor.closeCount, 1)
        subscription.dispose()
    }
}
