import Cocoa
import TGUIKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramContext

public enum BrowserLinkKind {
    case external
    case shareUrl
    case tonsite(String)
    case instantView
    case other
}

public enum BrowserLoginWidgetResult {
    case accepted(url: String?)
    case cancelled
    case failed
}

public enum BrowserPreparedShareResult: Equatable {
    case accepted
    case partiallyAccepted
    case rejected
    case unknown
    case cancelled
    case notAccepted
}

public protocol BrowserStickerView: AnyObject {
    func updateBrowserSticker(file: TelegramMediaFile, size: NSSize, context: any AccountContextProtocol, tint: NSColor?, animated: Bool)
}

public struct BrowserHooks {
    public let classifyLink: (any AccountContextProtocol, String) -> BrowserLinkKind
    public let openLink: (any AccountContextProtocol, String, Window?, Bool, @escaping () -> Void) -> Void
    public let resolveInstantView: (any AccountContextProtocol, String) -> Signal<TelegramMediaWebpage?, NoError>
    public let shareInlineQuery: (any AccountContextProtocol, String, [String]?, PeerId?, @escaping () -> Void) -> Void
    public let shareLink: (any AccountContextProtocol, String, Window) -> Void
    public let shareViaCallback: (any AccountContextProtocol, Window, @escaping ([PeerId]) -> Void) -> Void
    public let openPeerInfo: (any AccountContextProtocol, PeerId) -> Void
    public let openChat: (any AccountContextProtocol, PeerId) -> Void
    public var openChatWithContext: ((any AccountContextProtocol, PeerId) -> Void)?

    public func openChatObserved(_ context: any AccountContextProtocol, _ peerId: PeerId) {
        if let openChatWithContext {
            openChatWithContext(context, peerId)
        } else {
            openChat(context, peerId)
        }
    }

    public let sharePreparedMessage: (any AccountContextProtocol, Peer, PreparedInlineMessage, Window, @escaping (Bool) -> Void) -> Void
    public let openPremiumBoarding: (any AccountContextProtocol, Window) -> Void
    public let openInvoice: (any AccountContextProtocol, TelegramMediaInvoice, String, Window, @escaping (String) -> Void) -> Void
    public var openInvoiceWithContext: ((any AccountContextProtocol, TelegramMediaInvoice, String, Window, @escaping (String) -> Void) -> Void)?

    public func openInvoiceObserved(_ context: any AccountContextProtocol, _ invoice: TelegramMediaInvoice, _ slug: String, _ window: Window, completion: @escaping (String) -> Void) {
        let completed = Atomic(value: false)
        let observed: (String) -> Void = { status in
            guard ["paid", "failed", "cancelled", "pending"].contains(status), !completed.swap(true) else { return }
            completion(status)
        }
        if let openInvoiceWithContext {
            openInvoiceWithContext(context, invoice, slug, window, observed)
        } else {
            openInvoice(context, invoice, slug, window, observed)
        }
    }

    public let showLoginWidget: (any AccountContextProtocol, String, Peer, MessageActionUrlAuthResult.ClientData?, MessageActionUrlAuthResult.Flags, [String]?, EnginePeer.Id?, String, String?, @escaping (BrowserLoginWidgetResult) -> Void) -> Void
    public let makeRecommendedAppItem: (any AccountContextProtocol, TelegramUser, CGImage?, @escaping () -> Void) -> ContextMenuItem?
    public let makeInstantViewPage: (any AccountContextProtocol, TelegramMediaWebpage, String, String?, BrowserLinkManager) -> ViewController & BrowserPage
    public let showSavedToDownloads: (any AccountContextProtocol, Window, TextViewLayout) -> Void
    public let makeStickerView: (NSRect) -> NSView
    public let uploadStory: (any AccountContextProtocol, String, Peer, String?, Window) -> Void
    public let selectPeerForWebView: (any AccountContextProtocol, ReplyMarkupButtonRequestPeerType, PeerId, String, Int32, Int32, Window, @escaping (Bool) -> Void) -> Void
    public let makeSharePreviewMessageItem: (NSSize, any AccountContextProtocol, Message) -> TableRowItem
    public let makeShareChatContextResultModal: (any AccountContextProtocol, PreparedInlineMessage, @escaping (Bool) -> Void) -> ModalViewController
    public var makeShareChatContextResultModalWithContext: ((any AccountContextProtocol, PreparedInlineMessage, @escaping (Bool) -> Void) -> ModalViewController)?
    public var makeShareChatContextResultModalWithResult: ((any AccountContextProtocol, PreparedInlineMessage, @escaping (BrowserPreparedShareResult) -> Void) -> ModalViewController)?

    public func makeShareChatContextResultModalObservedResult(_ context: any AccountContextProtocol, _ preparedMessage: PreparedInlineMessage, completion: @escaping (BrowserPreparedShareResult) -> Void) -> ModalViewController {
        let completed = Atomic(value: false)
        let observed: (BrowserPreparedShareResult) -> Void = { value in
            do {
                guard !completed.swap(true) else { return }
                completion(value)
            }
        }
        let controller: ModalViewController
        if let makeShareChatContextResultModalWithResult {
            controller = makeShareChatContextResultModalWithResult(context, preparedMessage, observed)
        } else {
            controller = makeShareChatContextResultModalObserved(context, preparedMessage, completion: { observed($0 ? .accepted : .notAccepted) })
        }
        return controller
    }

    public func makeShareChatContextResultModalObserved(_ context: any AccountContextProtocol, _ preparedMessage: PreparedInlineMessage, completion: @escaping (Bool) -> Void) -> ModalViewController {
        let completed = Atomic(value: false)
        let observed: (Bool) -> Void = { value in
            do {
                guard !completed.swap(true) else { return }
                completion(value)
            }
        }
        let controller: ModalViewController
        if let makeShareChatContextResultModalWithContext {
            controller = makeShareChatContextResultModalWithContext(context, preparedMessage, observed)
        } else {
            controller = makeShareChatContextResultModal(context, preparedMessage, observed)
        }
        return controller
    }

    public init(classifyLink: @escaping (any AccountContextProtocol, String) -> BrowserLinkKind,
                openLink: @escaping (any AccountContextProtocol, String, Window?, Bool, @escaping () -> Void) -> Void,
                resolveInstantView: @escaping (any AccountContextProtocol, String) -> Signal<TelegramMediaWebpage?, NoError>,
                shareInlineQuery: @escaping (any AccountContextProtocol, String, [String]?, PeerId?, @escaping () -> Void) -> Void,
                shareLink: @escaping (any AccountContextProtocol, String, Window) -> Void,
                shareViaCallback: @escaping (any AccountContextProtocol, Window, @escaping ([PeerId]) -> Void) -> Void,
                openPeerInfo: @escaping (any AccountContextProtocol, PeerId) -> Void,
                openChat: @escaping (any AccountContextProtocol, PeerId) -> Void,
                sharePreparedMessage: @escaping (any AccountContextProtocol, Peer, PreparedInlineMessage, Window, @escaping (Bool) -> Void) -> Void,
                openPremiumBoarding: @escaping (any AccountContextProtocol, Window) -> Void,
                openInvoice: @escaping (any AccountContextProtocol, TelegramMediaInvoice, String, Window, @escaping (String) -> Void) -> Void,
                showLoginWidget: @escaping (any AccountContextProtocol, String, Peer, MessageActionUrlAuthResult.ClientData?, MessageActionUrlAuthResult.Flags, [String]?, EnginePeer.Id?, String, String?, @escaping (BrowserLoginWidgetResult) -> Void) -> Void,
                makeRecommendedAppItem: @escaping (any AccountContextProtocol, TelegramUser, CGImage?, @escaping () -> Void) -> ContextMenuItem?,
                makeInstantViewPage: @escaping (any AccountContextProtocol, TelegramMediaWebpage, String, String?, BrowserLinkManager) -> ViewController & BrowserPage,
                showSavedToDownloads: @escaping (any AccountContextProtocol, Window, TextViewLayout) -> Void,
                makeStickerView: @escaping (NSRect) -> NSView,
                uploadStory: @escaping (any AccountContextProtocol, String, Peer, String?, Window) -> Void,
                selectPeerForWebView: @escaping (any AccountContextProtocol, ReplyMarkupButtonRequestPeerType, PeerId, String, Int32, Int32, Window, @escaping (Bool) -> Void) -> Void,
                makeSharePreviewMessageItem: @escaping (NSSize, any AccountContextProtocol, Message) -> TableRowItem,
                makeShareChatContextResultModal: @escaping (any AccountContextProtocol, PreparedInlineMessage, @escaping (Bool) -> Void) -> ModalViewController) {
        self.classifyLink = classifyLink
        self.openLink = openLink
        self.resolveInstantView = resolveInstantView
        self.shareInlineQuery = shareInlineQuery
        self.shareLink = shareLink
        self.shareViaCallback = shareViaCallback
        self.openPeerInfo = openPeerInfo
        self.openChat = openChat
        self.sharePreparedMessage = sharePreparedMessage
        self.openPremiumBoarding = openPremiumBoarding
        self.openInvoice = openInvoice
        self.showLoginWidget = showLoginWidget
        self.makeRecommendedAppItem = makeRecommendedAppItem
        self.makeInstantViewPage = makeInstantViewPage
        self.showSavedToDownloads = showSavedToDownloads
        self.makeStickerView = makeStickerView
        self.uploadStory = uploadStory
        self.selectPeerForWebView = selectPeerForWebView
        self.makeSharePreviewMessageItem = makeSharePreviewMessageItem
        self.makeShareChatContextResultModal = makeShareChatContextResultModal
    }

    private static var value: BrowserHooks?

    public static var shared: BrowserHooks {
        guard let value = value else {
            preconditionFailure("BrowserHooks not installed")
        }
        return value
    }

    public static func install(_ hooks: BrowserHooks) {
        self.value = hooks
    }
}

public func installBrowserHooks(_ hooks: BrowserHooks) {
    BrowserHooks.install(hooks)
}
