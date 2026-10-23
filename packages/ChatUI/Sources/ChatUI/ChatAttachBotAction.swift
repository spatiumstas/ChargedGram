import AlertsUI
import Foundation
import Localization
import Postbox
import SwiftSignalKit
import TelegramContext
import TelegramCore
import TelegramUtils
import TGUIKit

private final class ChatBotConfirmation {

    private var resolved = false
    private var dismissalScheduled = false


    func resolve(_ action: () -> Void) {
        guard !resolved else { return }
        resolved = true
        action()
    }

    func dismissed() {
        guard !dismissalScheduled else { return }
        dismissalScheduled = true
        DispatchQueue.main.async {
            self.resolved = true
        }
    }
}

func chatOpenAttachBot(context: any AccountContextProtocol, peerId: PeerId, threadId: Int64?, replyId: MessageId?, botname: String, payload: String?) {
    let installed: Signal<Peer?, NoError> = context.engine.messages.attachMenuBots() |> map { items in
        for item in items {
            if item.peer.addressName?.lowercased() == botname.lowercased() {
                return item.peer._asPeer()
            }
        }
        return nil
    } |> take(1) |> deliverOnMainQueue
    var opened = false
    let openAttach: (Peer) -> Void = { peer in
        let open: () -> Void = {
            guard !opened else { return }
            opened = true
            let tab: ChatBrowserTab = .webapp(bot: .init(peer), peerId: peerId, buttonText: "", url: nil, payload: payload, threadId: threadId, replyTo: replyId, fromMenu: false)
            ChatNavigationHooks.shared.openBrowserTabObserved(context, tab)
        }
        guard peer.isVerified || peer.botInfo != nil else { return }
        let signal = context.engine.messages.getAttachMenuBot(botId: peer.id, cached: true) |> take(1)
        _ = (showModalProgress(signal: signal, for: context.window)).start(next: { attach in
            if attach.flags.contains(.showInSettingsDisclaimer) || attach.flags.contains(.notActivated) {
                var options: [ModalAlertData.Option] = []
                options.append(.init(string: strings().webBotAccountDisclaimerThird, isSelected: false, mandatory: true))
                var description: ModalAlertData.Description?
                let installBot = !attach.flags.contains(.notActivated) && attach.peer._asPeer().botInfo?.flags.contains(.canBeAddedToAttachMenu) == true && !attach.flags.contains(.showInAttachMenu)
                if installBot {
                    description = .init(string: strings().webBotAccountDesclaimerDesc(attach.shortName), onlyWhenEnabled: false)
                }
                let data = ModalAlertData(title: strings().webBotAccountDisclaimerTitle, info: strings().webBotAccountDisclaimerText, description: description, ok: strings().webBotAccountDisclaimerOK, options: options)
                let confirmation = ChatBotConfirmation()
                showModalAlert(for: context.window, data: data, completion: { _ in
                    confirmation.resolve {
                        _ = (context.engine.messages.acceptAttachMenuBotDisclaimer(botId: peer.id)).start()
                        ChatNavigationHooks.shared.installAttachMenuBotObserved(context, peer, completion: { value in
                            guard value else { return }
                            open()
                            showModalText(for: context.window, text: strings().webAppAttachSuccess(peer.displayTitle))
                        })
                    }
                }, cancel: {
                    confirmation.resolve {}
                }, onDeinit: {
                    confirmation.dismissed()
                })
            } else if attach.peer._asPeer().botInfo?.flags.contains(.canBeAddedToAttachMenu) == true {
                ChatNavigationHooks.shared.installAttachMenuBotObserved(context, peer, completion: { value in
                    if value { open() }
                })
            } else {
                open()
            }
        }, error: { _ in
            open()
        })
    }
    _ = (installed).start(next: { peer in
        if let peer {
            openAttach(peer)
        } else {
            let signal = ChatInterfaceHooks.shared.resolveUsername(botname, context) |> take(1)
            _ = (showModalProgress(signal: signal, for: context.window)).start(next: { peer in
                if let peer {
                    openAttach(peer)
                } else {
                    alert(for: context.window, info: strings().webAppAttachDoenstExist("@\(botname)"))
                }
            })
        }
    })
}

func chatOpenAttachMenuBot(_ bot: AttachMenuBot, context: any AccountContextProtocol, peerId: PeerId, threadId: Int64?, replyId: MessageId?) {
    var opened = false
    let open: () -> Void = {
        guard !opened else { return }
        opened = true
        ChatNavigationHooks.shared.openBrowserTabObserved(context, .webapp(bot: bot.peer, peerId: peerId, buttonText: "", url: nil, payload: nil, threadId: threadId, replyTo: replyId, fromMenu: false))
    }
    if bot.flags.contains(.showInSettingsDisclaimer) || bot.flags.contains(.notActivated) {
        let options: [ModalAlertData.Option] = [.init(string: strings().webBotAccountDisclaimerThird, isSelected: false, mandatory: true)]
        var description: ModalAlertData.Description?
        let installBot = !bot.flags.contains(.notActivated) && bot.peer._asPeer().botInfo?.flags.contains(.canBeAddedToAttachMenu) == true && !bot.flags.contains(.showInAttachMenu)
        if installBot {
            description = .init(string: strings().webBotAccountDesclaimerDesc(bot.shortName), onlyWhenEnabled: false)
        }
        let data = ModalAlertData(title: strings().webBotAccountDisclaimerTitle, info: strings().webBotAccountDisclaimerText, description: description, ok: strings().webBotAccountDisclaimerOK, options: options)
        let confirmation = ChatBotConfirmation()
        showModalAlert(for: context.window, data: data, completion: { _ in
            confirmation.resolve {
                _ = (context.engine.messages.acceptAttachMenuBotDisclaimer(botId: bot.peer.id)).start()
                ChatNavigationHooks.shared.installAttachMenuBotObserved(context, bot.peer._asPeer(), completion: { value in
                    guard value else { return }
                    if installBot {
                        showModalText(for: context.window, text: strings().webAppAttachSuccess(bot.peer._asPeer().displayTitle))
                    }
                    open()
                })
            }
        }, cancel: {
            confirmation.resolve {}
        }, onDeinit: {
            confirmation.dismissed()
        })
    } else {
        open()
    }
}
