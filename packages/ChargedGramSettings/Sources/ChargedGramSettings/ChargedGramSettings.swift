import Foundation

public final class ChargedGramSettings {
    public static let shared = ChargedGramSettings()
    public static let didChange = Notification.Name("ChargedGramSettings.didChange")

    private let defaults: UserDefaults
    private let notificationCenter: NotificationCenter
    private let keepChatsUnreadKey = "mod.keepChatsUnread"

    public init(defaults: UserDefaults = .standard, notificationCenter: NotificationCenter = .default) {
        self.defaults = defaults
        self.notificationCenter = notificationCenter
    }

    public var keepChatsUnread: Bool {
        get {
            return defaults.bool(forKey: keepChatsUnreadKey)
        }
        set {
            set(newValue, forKey: keepChatsUnreadKey)
        }
    }

    public var confirmCalls: Bool {
        get { defaults.bool(forKey: "chargedGram.confirmCalls") }
        set { set(newValue, forKey: "chargedGram.confirmCalls") }
    }

    public var hidePhoneNumbers: Bool {
        get { defaults.bool(forKey: "chargedGram.hidePhoneNumbers") }
        set { set(newValue, forKey: "chargedGram.hidePhoneNumbers") }
    }

    private func set(_ value: Bool, forKey key: String) {
        guard defaults.bool(forKey: key) != value else { return }
        defaults.set(value, forKey: key)
        notificationCenter.post(name: Self.didChange, object: self)
    }
}
