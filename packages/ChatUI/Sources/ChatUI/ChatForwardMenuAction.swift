import Postbox
import TelegramCore

final class ChatForwardMenuAction {
    private weak var chatInteraction: ChatInteraction?
    private let action: ChatDeferredSendAction

    init(chatInteraction: ChatInteraction, sources: [Message]) {
        self.chatInteraction = chatInteraction
        self.action = chatInteraction.captureDeferredSendAction()

    }

    func openPicker(messages: [Message]) {
        guard let chatInteraction, action.takeIfCurrent() else { return }
        chatInteraction.forwardMessages(messages)
    }

    func forward(_ object: ChatHistoryForwardMessagesObject, peerId: PeerId, threadId: Int64?) {
        guard let chatInteraction else { return }
        chatInteraction.quickForward(object, peerId: peerId, threadId: threadId, action: action)
    }
}
