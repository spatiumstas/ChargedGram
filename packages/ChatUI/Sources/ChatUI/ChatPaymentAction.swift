import Localization
import Postbox
import StarsUI
import SwiftSignalKit
import TelegramContext
import TelegramCore
import TelegramUtils
import TGUIKit

final class ChatPaidMediaPurchase {
    private let active = Atomic(value: false)
    private let request = MetaDisposable()

    func open(context: any AccountContextProtocol, messageId: MessageId, image: TelegramMediaImage, count: StarPurchaseType.PaidMediaCount) {
        guard !active.swap(true) else { return }
        let pending = MetaDisposable()
        request.set(pending)
        var receivedInvoice = false
        let signal = showModalProgress(signal: context.engine.payments.fetchBotPaymentInvoice(source: .message(messageId)) |> take(1) |> deliverOnMainQueue, for: context.window)
        pending.set((signal).start(next: { [weak self] invoice in
            guard let self else { return }
            receivedInvoice = true
            let controller = Star_PurschaseInApp(context: context, invoice: invoice, source: .message(messageId), type: .paidMedia(image, count))
            let onDeinit = controller.onDeinit
            controller.onDeinit = { [weak self] in
                onDeinit?()
                _ = self?.active.swap(false)
            }
            showModal(with: controller, for: context.window)
        }, error: { [weak self] _ in
            guard let self else { return }
            _ = self.active.swap(false)
            showModalText(for: context.window, text: strings().paymentsInvoiceNotExists)
        }, completed: { [weak self] in
            if !receivedInvoice { _ = self?.active.swap(false) }
        }))
    }

    deinit {
        request.dispose()
    }
}

func openChatMessagePayment(context: any AccountContextProtocol, messageId: MessageId, invoice: TelegramMediaInvoice) {
    if let receiptMessageId = invoice.receiptMessageId {
        ChatNavigationHooks.shared.showPaymentsReceiptObserved(context, receiptMessageId, invoice, context.window)
    } else if invoice.currency == XTR {
        showModal(with: Star_PurschaseInApp(context: context, invoice: invoice, source: .message(messageId)), for: context.window)
    } else {
        ChatNavigationHooks.shared.showPaymentsCheckoutObserved(context, messageId, invoice, context.window)
    }
}
