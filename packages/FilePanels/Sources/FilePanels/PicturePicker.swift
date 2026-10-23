import Cocoa
import TGUIKit
import TelegramTheme
import Quartz

fileprivate class PickerObserver {
    fileprivate var completion: ((NSImage?) -> Void)?
    
    @objc fileprivate func validated(_ picker:IKPictureTaker, _ code:Int, _ contextInfo:Any?) {
        guard let completion = self.completion else { return }
        self.completion = nil
        if activePicturePicker === self {
            activePicturePicker = nil
        }
        if code == NSApplication.ModalResponse.OK.rawValue {
            var image = picker.outputImage()
            if let img = image {
                let size = img.size.aspectFilled(NSMakeSize(640, 640))
                let resized = generateImage(size, contextGenerator: { size, ctx in
                    ctx.clear(NSMakeRect(0, 0, size.width, size.height))
                    ctx.draw(img.precomposed(), in: NSMakeRect(0, 0, size.width, size.height))
                })!
                image = NSImage(cgImage: resized, size: size)
            }
            completion(image)
        } else {
            completion(nil)
        }
    }
}

private var activePicturePicker: PickerObserver?


public func pickImage(for window:Window, maxSize:NSSize = NSMakeSize(640, 640), fileFirst: Bool = false, completion:@escaping (NSImage?) -> Void) {
    guard activePicturePicker == nil else {
        completion(nil)
        return
    }
    let observer = PickerObserver()
    activePicturePicker = observer
    let taker:IKPictureTaker = IKPictureTaker.pictureTaker()
    taker.setValue(NSNumber(value: true), forKey: IKPictureTakerShowEffectsKey)
    taker.setValue(NSValue(size: maxSize), forKey: IKPictureTakerOutputImageMaxSizeKey)
    if fileFirst {
    }
    observer.completion = { image in
        completion(image)
    }
    
    if let window = NSApp.window(withWindowNumber: taker.windowNumber) {
        window.appearance = theme.appearance
    }


    taker.beginSheet(for: window, withDelegate: observer, didEnd: #selector(PickerObserver.validated(_:_:_:)), contextInfo: nil)
    
    
    
        //.appearance = theme.appearance

}
