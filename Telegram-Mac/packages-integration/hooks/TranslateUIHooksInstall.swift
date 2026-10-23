import Cocoa
import TGUIKit
import TelegramCore
import TranslateUI

func installTranslateUIHooks() {
    var hooks = TranslateUIHooks(showAboutCocoonModal: { context in
        showAboutCocoonModal(context: context as! AccountContext)
    }, shareLink: { context, link in
        let context = context as! AccountContext
        showModal(with: ShareModalController(ShareLinkObject(context, link: link)), for: context.window)
    }, followResolvedName: { handle, username, context in
        execute(inapp: .followResolvedName(link: handle, username: username, postId: nil, forceProfile: true, context: context as! AccountContext, action: nil, callback: { _, _, _, _ in }))
    }, showStyleEmojiPicker: { context, control, selected in
        let context = context as! AccountContext
        let emojis = EmojiesController(context, mode: .status, ignorePremium: true)
        emojis._frameRect = NSMakeRect(0, 0, 350, 300)

        let interactions = EntertainmentInteractions(.emoji, peerId: context.peerId)
        emojis.update(with: interactions, chatInteraction: ChatInteraction(chatLocation: .peer(context.peerId), context: context))

        interactions.sendAnimatedEmoji = { sticker, _, _, _, _ in
            let file = sticker.file._parse()
            selected(file)
            closeAllPopovers(for: context.window)
        }

        showPopover(for: control, with: emojis)
    })
    hooks.shareLinkWithContext = { context, link in
        showModal(with: ShareModalController(ShareLinkObject(context, link: link)), for: context.window)
    }
    hooks.showAboutCocoonModalWithContext = { context in
        showAboutCocoonModal(context: context as! AccountContext)
    }
    hooks.showStyleEmojiPickerWithContext = { context, control, selected in
        let context = context as! AccountContext
        let emojis = EmojiesController(context, mode: .status, ignorePremium: true)
        emojis.showsGlassSurface = true
        emojis._frameRect = NSMakeRect(0, 0, 350, 300)
        let interactions = EntertainmentInteractions(.emoji, peerId: context.peerId)
        let chatInteraction = ChatInteraction(chatLocation: .peer(context.peerId), context: context)
        emojis.update(with: interactions, chatInteraction: chatInteraction)
        interactions.sendAnimatedEmoji = { sticker, _, _, _, _ in
            selected(sticker.file._parse())
            closeAllPopovers(for: context.window)
        }
        showPopover(for: control, with: emojis)
    }
    hooks.followResolvedNameWithContext = { handle, username, context in
        execute(inapp: .followResolvedName(link: handle, username: username, postId: nil, forceProfile: true, context: context as! AccountContext, action: nil, callback: { _, _, _, _ in }))
    }
    TranslateUIHooks.install(hooks)
}
