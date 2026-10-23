import Cocoa
import TGUIKit
import Postbox
import GroupsInCommonUI

func installGroupsInCommonUIHooks() {
    var hooks = GroupsInCommonHooks(
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
    GroupsInCommonHooks.install(hooks)
}
