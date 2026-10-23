import AlertsUI
import Dispatch
import SwiftSignalKit
import TGUIKit

func sharePickerConfirmation(window: Window, header: String, information: String, ok: String) -> Signal<Bool, NoError> {
    return Signal { subscriber in
        verifyAlert(for: window, header: header, information: information, ok: ok, successHandler: { _ in
            subscriber.putNext(true)
            subscriber.putCompletion()
        }, cancelHandler: {
            subscriber.putNext(false)
            subscriber.putCompletion()
        }, onDeinit: {
            DispatchQueue.main.async {
                do {
                    subscriber.putCompletion()
                }
            }
        })
        return EmptyDisposable
    } |> take(1)
}
