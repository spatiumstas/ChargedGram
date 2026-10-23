import Cocoa
import TGUIKit
import Postbox
import PeerInfoUI

func installSimilarPeersUIHooks() {
    var hooks = SimilarPeersHooks(
        openChat: { context, peerId in
        guard let context = context as? AccountContext else {
            return
        }
        let controller = ChatAdditionController(context: context, chatLocation: .peer(peerId))
        context.bindings.rootNavigation().push(controller) }
    )
    hooks.openChatWithContext = { context, peerId in
        guard let context = context as? AccountContext else { return }
        let controller = ChatAdditionController(context: context, chatLocation: .peer(peerId))
        context.bindings.rootNavigation().push(controller)
    }
    SimilarPeersHooks.install(hooks)
}
