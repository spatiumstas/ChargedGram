import Cocoa
import MapKit
import TGUIKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramContext

public protocol LocationChatInteraction: AnyObject {
    var locationContext: (any AccountContextProtocol) { get }
    var locationPeerId: PeerId { get }
    func sendPickedLocation(_ coordinate: CLLocationCoordinate2D, _ venue: MapVenue?)
}

public struct LocationHooks {
    public let confirmSend: (any LocationChatInteraction, @escaping () -> Void) -> Void

    public var confirmSendWithContext: ((any LocationChatInteraction, @escaping () -> Void) -> Void)?

    public func confirmSendObserved(_ interaction: any LocationChatInteraction, invoke: @escaping () -> Void) {
        let context = interaction.locationContext
        let confirmed = {
            invoke()
        }
        if let confirmSendWithContext {
            confirmSendWithContext(interaction, confirmed)
        } else {
            confirmSend(interaction) {
                confirmed()
            }
        }
    }

    public init(confirmSend: @escaping (any LocationChatInteraction, @escaping () -> Void) -> Void) {
        self.confirmSend = confirmSend
    }

    private static var value: LocationHooks?

    public static var shared: LocationHooks {
        guard let value = value else {
            preconditionFailure("LocationHooks not installed")
        }
        return value
    }

    public static func install(_ hooks: LocationHooks) {
        self.value = hooks
    }
}

public func installLocationHooks(_ hooks: LocationHooks) {
    LocationHooks.install(hooks)
}
