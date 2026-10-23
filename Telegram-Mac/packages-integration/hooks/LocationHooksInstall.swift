import Cocoa
import MapKit
import TGUIKit
import Postbox
import TelegramCore
import SwiftSignalKit
import LocationUI

func installLocationUIHooks() {
    let confirmSend: (any LocationChatInteraction, @escaping () -> Void) -> Void = { interaction, invoke in
        let accountContext = interaction.locationContext
        guard let chatInteraction = interaction as? ChatInteraction else {
            invoke()
            return
        }
        let presentation = chatInteraction.presentation
        let context = chatInteraction.context

        let messagesCount = 1

        guard let payStars = presentation.sendPaidMessageStars, let peer = presentation.peer, let starsState = presentation.starsState else {
            invoke()
            return
        }
        let starsPrice = Int(payStars.value * Int64(messagesCount))
        let amount = strings().starListItemCountOther(starsPrice)

        let buyMore:()->Void = {
            showModal(with: Star_ListScreen(context: context, source: .buy(suffix: nil, amount: Int64(starsPrice))), for: context.window)
        }

        if !presentation.alwaysPaidMessage {
            let messageCountText = strings().chatPayStarsConfirmMessagesOther(messagesCount)
            verifyAlert(for: context.window, header: strings().chatPayStarsConfirmTitle, information: strings().chatPayStarsConfirmText(peer.displayTitle, amount, amount, messageCountText), ok: strings().chatPayStarsConfirmPayOther(messagesCount), option: strings().chatPayStarsConfirmCheckbox, optionIsSelected: false, successHandler: { result in
                if starsState.balance.value > starsPrice {
                    chatInteraction.update({ current in
                        return current
                            .withUpdatedAlwaysPaidMessage(result == .thrid)
                    })
                    if result == .thrid {
                        FastSettings.toggleCofirmPaid(peer.id, price: starsPrice)
                    }
                    invoke()
                } else {
                    buyMore()
                }
            })
        } else {
            if starsState.balance.value > starsPrice {
                invoke()
            } else {
                buyMore()
            }
        }
    }
    var hooks = LocationHooks(confirmSend: { interaction, invoke in
        confirmSend(interaction, invoke)
    })
    hooks.confirmSendWithContext = confirmSend
    installLocationHooks(hooks)
}

