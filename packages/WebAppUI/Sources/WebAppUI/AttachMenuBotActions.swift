import Cocoa
import Foundation
import WebKit
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit
import Localization
import ColorPalette
import InAppSettings
import FoundationUtils
import ObjcUtils
import KeyboardKey
import TelegramIconsTheme
import TelegramMedia
import TelegramTheme
import TelegramContext
import TelegramUtils
import GeneralRows
import InputDataUI
import AvatarUI
import AlertsUI
import LocalAnimations
import FilePanels
import TelegramLinks
import PremiumStatusUI
import SystemPermissions
import Svg
import LocalAuthentication


public func installAttachMenuBot(context: any AccountContextProtocol, peer: Peer, completion: @escaping (Bool) -> Void) {
    let signal = context.engine.messages.addBotToAttachMenu(botId: peer.id, allowWrite: true) |> take(1) |> deliverOnMainQueue
    _ = signal.start(next: { value in
        if value { completion(value) }
    })
}


public func openWebBot(_ bot: AttachMenuBot, context: any AccountContextProtocol) {
    let tab: BrowserTabData.Data = .simple(bot: bot.peer, url: nil, buttonText: "", source: .settings)
    var opened = false
    let open: () -> Void = {
        guard !opened else { return }
        opened = true
        do {
            BrowserStateContext.get(context).open(tab: tab)
        }
    }
    if bot.flags.contains(.showInSettingsDisclaimer) || bot.flags.contains(.notActivated) {
        let options: [ModalAlertData.Option] = [.init(string: strings().webBotAccountDisclaimerThird, isSelected: false, mandatory: true)]
        var description: ModalAlertData.Description?
        let installBot = !bot.flags.contains(.notActivated) && bot.peer._asPeer().botInfo?.flags.contains(.canBeAddedToAttachMenu) == true && !bot.flags.contains(.showInAttachMenu)
        if installBot {
            description = .init(string: strings().webBotAccountDesclaimerDesc(bot.shortName), onlyWhenEnabled: false)
        }
        let data = ModalAlertData(title: strings().webBotAccountDisclaimerTitle, info: strings().webBotAccountDisclaimerText, description: description, ok: strings().webBotAccountDisclaimerOK, options: options)
        let decision = BrowserDecision()
        showModalAlert(for: context.window, data: data, completion: { _ in
            decision.resolve {
                _ = (context.engine.messages.acceptAttachMenuBotDisclaimer(botId: bot.peer.id)).start()
                installAttachMenuBot(context: context, peer: bot.peer._asPeer(), completion: { value in
                    guard value else { return }
                    if installBot {
                        showModalText(for: context.window, text: strings().webAppAttachSuccess(bot.peer._asPeer().displayTitle))
                    }
                    open()
                })
            }
        }, cancel: {
            decision.resolve {}
        }, onDeinit: {
            decision.dismissed()
        })
    } else {
        open()
    }
}


public func openJoinChatBotWebView(context: any AccountContextProtocol, botId: PeerId, url: String?, queryId: Int64, joinedPeerId: PeerId?) {
    BrowserStateContext.get(context).openJoinChatWebView(botId: botId, url: url, queryId: queryId, peerId: joinedPeerId)
}
