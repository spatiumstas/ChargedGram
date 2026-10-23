import InputDataUI
import SwiftSignalKit
import TelegramContext
import TelegramCore
import TGUIKit

final class StarsScreenContext {
    let disposables = DisposableSet()
    let purchase = StarPurchaseSession()
    private let closed = Atomic(value: false)

    var isOpen: Bool { !closed.with { $0 } }

    init(context: any AccountContextProtocol, source: Star_ListScreenSource) {
    }

    func action(_ callback: @escaping () -> Void) -> () -> Void {
        return {
            guard self.isOpen else { return }
            callback()
        }
    }

    func action<Value>(_ callback: @escaping (Value) -> Void) -> (Value) -> Void {
        return { value in self.action { callback(value) }() }
    }

    func preserving<Value, Failure>(_ signal: Signal<Value, Failure>) -> Signal<Value, Failure> {
        return Signal { subscriber in
            guard self.isOpen else {
                subscriber.putCompletion()
                return EmptyDisposable
            }
            return (signal).start(next: { value in
                if self.isOpen { subscriber.putNext(value) }
            }, error: { error in
                if self.isOpen { subscriber.putError(error) }
            }, completed: {
                subscriber.putCompletion()
            })
        }
    }

    func showChild(_ build: () -> ModalViewController, show: (ModalViewController) -> Void) {
        guard isOpen else { return }
        let controller = build()
        guard isOpen else { return }
        show(controller)
    }

    func close() {
        guard !closed.swap(true) else { return }
        _ = purchase.close()
        disposables.dispose()
    }
}
