import Cocoa
import RLottie
import TLottie

extension RLottieBridge: @retroactive LottieFrameRenderer {}
extension TLottieBridge: @retroactive LottieFrameRenderer {}

func installLottieRenderHooks() {
    LottieRenderHooks.install(LottieRenderHooks(makeRenderer: { json, key in
        if LottieBackend.usesTLottie {
            return TLottieBridge(json: json)
        }
        return RLottieBridge(json: json, key: key)
    }))
}
