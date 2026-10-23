import Cocoa
import SettingsUI

func installDeveloperUIHooks() {
    DeveloperHooks.install(DeveloperHooks(
        updateGraphicContext: {
        appDelegate?.updateGraphicContext() },
        forceRLottieBackend: {
            return LottieBackend.forceRLottie
        },
        toggleForceRLottieBackend: {
            LottieBackend.forceRLottie = !LottieBackend.forceRLottie
        }
    ))
}
