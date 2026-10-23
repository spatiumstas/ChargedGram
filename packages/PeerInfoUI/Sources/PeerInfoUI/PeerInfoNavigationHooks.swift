import Cocoa
import TGUIKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramContext
import ChatHistoryModel
import InviteLinksUI

public enum PeerInfoFragmentSubject {
    case username(String)
    case phoneNumber(String)
}

public struct PeerInfoNavigationHooks {
    public var makeGroupsInCommonController: (any AccountContextProtocol, PeerId) -> ViewController = { _, _ in ViewController() }
    public var makeGroupsInCommonControllerWithContext: ((any AccountContextProtocol, PeerId) -> ViewController)?
    public func makeGroupsInCommonControllerObserved(_ context: any AccountContextProtocol, _ peerId: PeerId) -> ViewController {
        let controller = makeGroupsInCommonControllerWithContext?(context, peerId) ?? makeGroupsInCommonController(context, peerId)
        return controller
    }
    public var openQrStudio: (any AccountContextProtocol, PeerId, (() -> NSView?)?) -> Void = { _, _, _ in }
    public var openQrStudioWithContext: ((any AccountContextProtocol, PeerId, (() -> NSView?)?) -> Void)?

    public func openQrStudioObserved(_ context: any AccountContextProtocol, _ peerId: PeerId, _ morphSource: (() -> NSView?)?) {
        if let openQrStudioWithContext {
            openQrStudioWithContext(context, peerId, morphSource)
        } else {
            do {
                openQrStudio(context, peerId, morphSource)
            }
        }
    }
    public var prefetchQrStudio: (any AccountContextProtocol, Peer) -> Void = { _, _ in }
    public var showTranslateModal: (any AccountContextProtocol, String?, String, String) -> Void = { _, _, _, _ in }
    public var makeChannelVisibilityController: (any AccountContextProtocol, PeerId, Bool, InviteLinkPeerManager?) -> (controller: ViewController, onComplete: Signal<PeerId?, NoError>) = { _, _, _, _ in (ViewController(), .never()) }
    public var makeChannelDiscussionSetupController: (any AccountContextProtocol, Peer) -> ViewController = { _, _ in ViewController() }
    public var makeWelcomeMessageController: (any AccountContextProtocol, PeerId) -> ViewController = { _, _ in ViewController() }
    public var makeGroupStickerSetController: (any AccountContextProtocol, PeerId) -> ViewController = { _, _ in ViewController() }
    public var makeGroupReactionsSettingsController: (any AccountContextProtocol, PeerId, PeerAllowedReactions?, AvailableReactions?) -> ViewController = { _, _, _, _ in ViewController() }
    public var showChannelReactions: (any AccountContextProtocol, PeerId, PeerAllowedReactions?, AvailableReactions, Int32?, Bool?) -> Void = { _, _, _, _, _, _ in }
    public var makeSuggestPostController: (any AccountContextProtocol, PeerId) -> ViewController = { _, _ in ViewController() }
    public var makeForumTopicEditController: (any AccountContextProtocol, PeerId, MessageHistoryThreadData, Int64) -> ViewController = { _, _, _, _ in ViewController() }
    public var makeForumSettingsController: (any AccountContextProtocol, PeerId) -> ViewController = { _, _ in ViewController() }
    public var openFragment: (any AccountContextProtocol, PeerId, PeerInfoFragmentSubject, @escaping (String) -> Void) -> Void = { _, _, _, _ in }
    public var makeStarMonetizationController: (any AccountContextProtocol, PeerId, StarsRevenueStatsContext) -> ViewController = { _, _, _ in ViewController() }
    public var makeTonMonetizationController: (any AccountContextProtocol, PeerId, StarsRevenueStatsContext) -> ViewController = { _, _, _ in ViewController() }
    public var showRestrictMember: (any AccountContextProtocol, PeerId, PeerId, ChannelParticipant, @escaping (TelegramChatBannedRights?) -> Void) -> Void = { _, _, _, _, _ in }
    public var showChannelParticipant: (any AccountContextProtocol, PeerId, RenderedChannelParticipant) -> Void = { _, _, _ in }
    public var showRestrictMemberWithContext: ((any AccountContextProtocol, PeerId, PeerId, ChannelParticipant, @escaping (TelegramChatBannedRights?) -> Void) -> Void)?
    public func showRestrictMemberObserved(_ context: any AccountContextProtocol, _ peerId: PeerId, _ memberId: PeerId, _ participant: ChannelParticipant, _ updated: @escaping (TelegramChatBannedRights?) -> Void) {
        let completion: (TelegramChatBannedRights?) -> Void = { rights in
            updated(rights)
        }
        if let showRestrictMemberWithContext {
            showRestrictMemberWithContext(context, peerId, memberId, participant, completion)
        } else {
            showRestrictMember(context, peerId, memberId, participant, completion)
        }
    }
    public var showChannelParticipantWithContext: ((any AccountContextProtocol, PeerId, RenderedChannelParticipant) -> Void)?
    public func showChannelParticipantObserved(_ context: any AccountContextProtocol, _ peerId: PeerId, _ participant: RenderedChannelParticipant) {
        if let showChannelParticipantWithContext {
            showChannelParticipantWithContext(context, peerId, participant)
        } else {
            showChannelParticipant(context, peerId, participant)
        }
    }
    public var makeChannelMembersController: (any AccountContextProtocol, PeerId) -> ViewController = { _, _ in ViewController() }
    public var makeChannelBlacklistController: (any AccountContextProtocol, PeerId) -> ViewController = { _, _ in ViewController() }
    public var makeChannelPermissionsController: (any AccountContextProtocol, PeerId) -> ViewController = { _, _ in ViewController() }
    public var showUserTagInfo: (any AccountContextProtocol, String, String, String, AdminBadgeType, Bool) -> Void = { _, _, _, _, _, _ in }
    public var showUserTagInfoWithContext: ((any AccountContextProtocol, String, String, String, AdminBadgeType, Bool) -> Void)?
    public func showUserTagInfoObserved(_ context: any AccountContextProtocol, _ tag: String, _ authorName: String, _ groupName: String, _ badgeType: AdminBadgeType, _ canEditRank: Bool) {
        if let showUserTagInfoWithContext {
            showUserTagInfoWithContext(context, tag, authorName, groupName, badgeType, canEditRank)
        } else {
            showUserTagInfo(context, tag, authorName, groupName, badgeType, canEditRank)
        }
    }

    public var makeSelectColorController: (any AccountContextProtocol, Peer) -> ViewController = { _, _ in ViewController() }
    public var peerColorsLabelIcon: (Peer?, any AccountContextProtocol) -> CGImage = { _, _ in generateImage(NSMakeSize(1, 1), contextGenerator: { _, _ in })! }
    public var editAccountInfo: (any AccountContextProtocol, @escaping (ViewController) -> Void) -> Void = { _, _ in }

    public init() {
    }

    private static var _shared = PeerInfoNavigationHooks()

    public static var shared: PeerInfoNavigationHooks {
        return _shared
    }

    public static func install(_ hooks: PeerInfoNavigationHooks) {
        assert(Thread.isMainThread, "PeerInfoNavigationHooks.install must be called on the main thread")
        _shared = hooks
    }
}
