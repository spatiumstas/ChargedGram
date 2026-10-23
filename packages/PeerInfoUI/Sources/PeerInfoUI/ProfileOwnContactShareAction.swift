import AlertsUI
import ChatHistoryModel
import Dispatch
import Localization
import Postbox
import SwiftSignalKit
import TelegramContext
import TelegramCore
import TGUIKit

final class ProfileOwnContactShareAction {
    private let disposable = MetaDisposable()
    private var generation: UInt64 = 0
    private var pending: UInt64?
    private var confirmation: UInt64?

    func reset() {
        generation &+= 1
        pending = nil
        confirmation = nil
        disposable.set(nil)
    }

    private func isCurrent(_ generation: UInt64) -> Bool {
        return pending == generation
    }

    private func request<Value>(_ generation: UInt64, build: () -> Signal<Value, NoError>, next: @escaping (Value) -> Void, empty: (() -> Void)? = nil) {
        guard isCurrent(generation) else { return }
        let subscription = MetaDisposable()
        disposable.set(subscription)
        guard isCurrent(generation) else { return }
        let signal = build()
        guard isCurrent(generation) else { return }
        var received = false
        subscription.set((signal |> take(1) |> deliverOnMainQueue).start(next: { [weak self] value in
            guard self?.isCurrent(generation) == true else { return }
            received = true
            next(value)
        }, completed: { [weak self] in
            guard let self, self.isCurrent(generation), !received else { return }
            if let empty { empty() } else { self.reset() }
        }))
    }

    func start(context: any AccountContextProtocol, peerId: PeerId) {
        guard pending == nil else { return }
        generation &+= 1
        let generation = self.generation
        pending = generation
        request(generation, build: {
            context.account.postbox.transaction { $0.getPeer(peerId) }
        }, next: { [weak self] peer in
            guard let self else { return }
            guard let peer else {
                self.reset()
                return
            }
            self.confirmation = generation
            guard self.isCurrent(generation) else { return }
            verifyAlert_button(for: context.window, information: strings().peerInfoConfirmShareInfo(peer.displayTitle), successHandler: { [weak self] _ in
                do {
                    guard let self, self.isCurrent(generation), self.confirmation == generation else { return }
                    self.confirmation = nil
                    self.send(generation, context: context, peerId: peerId)
                }
            }, cancelHandler: { [weak self] in
                do {
                    guard let self, self.isCurrent(generation), self.confirmation == generation else { return }
                    self.confirmation = nil
                    self.reset()
                }
            }, onDeinit: { [weak self] in
                DispatchQueue.main.async {
                    do {
                        guard let self, self.isCurrent(generation), self.confirmation == generation else { return }
                        self.reset()
                    }
                }
            })
        })
    }

    private func send(_ generation: UInt64, context: any AccountContextProtocol, peerId: PeerId) {
        request(generation, build: {
            context.account.postbox.transaction { $0.getPeer(context.peerId) }
        }, next: { [weak self] peer in
            guard let self else { return }
            guard let peer = peer as? TelegramUser, peer.id == context.peerId else {
                self.reset()
                return
            }
            self.request(generation, build: {
                let message = EnqueueMessage.message(text: "", attributes: [], inlineStickers: [:], mediaReference: AnyMediaReference.standalone(media: TelegramMediaContact(firstName: peer.firstName ?? "", lastName: peer.lastName ?? "", phoneNumber: peer.phone ?? "", peerId: peer.id, vCardData: nil)), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                var terminal = false
                let signal = Sender.enqueue(message: message, context: context, peerId: peerId)
                |> beforeNext { _ in terminal = true }
                |> beforeCompleted { terminal = true }
                |> afterDisposed { [weak self] in
                    guard !terminal, let self, self.isCurrent(generation) else { return }
                    self.reset()
                }
                return showModalProgress(signal: signal, for: context.window)
            }, next: { [weak self] result in
                self?.complete(result)
            }, empty: { [weak self] in self?.complete(nil) })
        })
    }

    private func complete(_ result: [MessageId?]?) {
        reset()
    }

    deinit {
        disposable.dispose()
    }
}
