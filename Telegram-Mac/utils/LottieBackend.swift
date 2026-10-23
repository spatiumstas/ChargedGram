import Foundation
import TelegramCore

enum LottieBackend {
    private static let forceRLottieKey = "kForceRLottieBackend"
    private static let serverDisabledKey = "kTLottieServerDisabled"

    static var forceRLottie: Bool {
        get {
            return UserDefaults.standard.bool(forKey: forceRLottieKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: forceRLottieKey)
        }
    }

    static var usesTLottie: Bool {
        return !forceRLottie && !UserDefaults.standard.bool(forKey: serverDisabledKey)
    }

    static func update(appConfiguration: AppConfiguration) {
        let disabled = appConfiguration.data?["macos_killswitch_disable_tlottie"] != nil
        if UserDefaults.standard.bool(forKey: serverDisabledKey) != disabled {
            UserDefaults.standard.set(disabled, forKey: serverDisabledKey)
        }
    }
}
