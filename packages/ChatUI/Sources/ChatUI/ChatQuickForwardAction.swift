import Postbox
import SwiftSignalKit
import TelegramContext

final class ChatQuickForwardAction {
    private let disposable = MetaDisposable()
    private var generation: UInt64 = 0
    private var pending: UInt64?

    func reset() {
        generation &+= 1
        pending = nil
        disposable.set(nil)
    }

    func start(context: any AccountContextProtocol, peerId: PeerId, threadId: Int64?, isCurrent: () -> Bool, request: () -> Signal<ChatHistoryForwardResult, String>) {
        guard pending == nil, isCurrent() else { return }
        generation &+= 1
        let generation = self.generation
        pending = generation
        let subscription = MetaDisposable()
        disposable.set(subscription)
        let signal = request()
        guard pending == generation else { return }
        subscription.set((signal |> take(1) |> deliverOnMainQueue).start(next: { [weak self] _ in
            guard let self, self.pending == generation else { return }
            self.reset()
        }, error: { [weak self] _ in
            guard let self, self.pending == generation else { return }
            self.reset()
        }, completed: { [weak self] in
            guard let self, self.pending == generation else { return }
            self.reset()
        }))
    }

    deinit {
        disposable.dispose()
    }
}
