import Cocoa
import TGUIKit
import SwiftSignalKit
import ColorPalette
import Localization
import TelegramTheme
import TelegramMediaUtils

public struct EditedImageData : Equatable {

    public enum UndoRedoAction : Equatable {
        case images([Image], AnyHashable?)
    }

    public struct Image : Equatable {
        public let url: URL
        public let img: NSImage
        public let stableId: AnyHashable
        public var rect: NSRect
        public var multiplier: CGSize = NSMakeSize(1, 1)
        public var rotation: CGFloat

        public init(url: URL, img: NSImage, stableId: AnyHashable, rect: NSRect, multiplier: CGSize = NSMakeSize(1, 1), rotation: CGFloat) {
            self.url = url
            self.img = img
            self.stableId = stableId
            self.rect = rect
            self.multiplier = multiplier
            self.rotation = rotation
        }

        public func new(_ stableId: AnyHashable) -> Image {
            return .init(url: self.url, img: self.img, stableId: stableId, rect: self.rect, multiplier: self.multiplier, rotation: self.rotation)
        }
    }

    public var originalUrl: URL
    public var selectedRect: NSRect = .zero
    public var orientation: ImageOrientation?
    public var dimensions: SelectionRectDimensions  = .none
    public var isHorizontalFlipped: Bool = false
    public var paintings: [EditImageDrawTouch] = []
    public var entities: [EditImageCanvasEntity] = []
    public var selectedImage: AnyHashable?
    public var images: [Image] = []

    public var undo: [UndoRedoAction] = []
    public var redo: [UndoRedoAction] = []

    public init(originalUrl: URL, selectedRect: NSRect = .zero, orientation: ImageOrientation? = nil, dimensions: SelectionRectDimensions = .none, isHorizontalFlipped: Bool = false, paintings: [EditImageDrawTouch] = [], entities: [EditImageCanvasEntity] = [], selectedImage: AnyHashable? = nil, images: [Image] = [], undo: [UndoRedoAction] = [], redo: [UndoRedoAction] = []) {
        self.originalUrl = originalUrl
        self.selectedRect = selectedRect
        self.orientation = orientation
        self.dimensions = dimensions
        self.isHorizontalFlipped = isHorizontalFlipped
        self.paintings = paintings
        self.entities = entities
        self.selectedImage = selectedImage
        self.images = images
        self.undo = undo
        self.redo = redo
    }

    public var hasntData: Bool {
        return orientation == nil && dimensions == .none && !isHorizontalFlipped && paintings.isEmpty && entities.isEmpty && images.isEmpty
    }

    public func makeImage(_ image: CGImage, interface: Bool, applyPainting: Bool = true) -> CGImage {
        return EditedImageData.makeImage(image, data: self, interface: interface, applyPainting: applyPainting)
    }

    public func isNeedToRegenerate(_ data: EditedImageData?) -> Bool {
        if let other = data {
            if other.orientation != self.orientation {
                return true
            }
            if other.isHorizontalFlipped != self.isHorizontalFlipped {
                return true
            }
            if other.paintings != self.paintings {
                return true
            }
            if other.entities != self.entities {
                return true
            }
            return false
        } else {
            return true
        }
    }
    
    fileprivate static func makeImage(_ image: CGImage, data: EditedImageData, interface: Bool, applyPainting: Bool = true) -> CGImage {
        var image: CGImage = image
        var orientation = data.orientation
        
        if !data.paintings.isEmpty || !data.entities.isEmpty, applyPainting {
            let source = image
            let blurImage = data.paintings.contains(where: { $0.action == .blur || $0.action == .blurAll }) ? editImageCanvasBlurredImage(source) : nil
            image = generateImage(image.size, scale: 1.0, rotatedContext: { size, context in
                let rect = NSMakeRect(0, 0, size.width, size.height)
                context.clear(rect)
                
                context.saveGState()
                context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                context.scaleBy(x: 1, y: -1.0)
                context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                context.draw(image, in: rect)
                context.restoreGState()
                
                let paints = generateImage(size, contextGenerator: { size, ctx in
                    ctx.clear(rect)
                    applyPaints(data.paintings, for: ctx, imageSize: size, blurImage: blurImage)
                    applyEntities(data.entities, for: ctx, size: size)
                }, scale: 1.0)!
                
                context.draw(paints, in: rect)
                
            })!
        }
        
        if data.isHorizontalFlipped, let temp = orientation {
            switch temp {
            case .left:
                orientation = .leftMirrored
            case .right:
                orientation = .rightMirrored
            case .down:
                orientation = .downMirrored
            default:
                orientation = nil
            }
        }
        if let orientation = orientation {
            image = image.createMatchingBackingDataWithImage(orienation: orientation)!
        } else if data.isHorizontalFlipped {
            return generateImage(image.size, contextGenerator: { size, ctx in
                ctx.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                ctx.scaleBy(x: -1.0, y: 1.0)
                ctx.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                
                ctx.draw(image, in: NSMakeRect(0, 0, size.width, size.height))
                
                ctx.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                ctx.scaleBy(x: -1.0, y: 1.0)
                ctx.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
            }, scale: 1.0)!
        }
        
        if !data.images.isEmpty, !interface {
            image = generateImage(image.size, contextGenerator: { size, context in
                let rect = NSMakeRect(0, 0, size.width, size.height)
                context.clear(rect)
                
                context.draw(image, in: rect)
                
                context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                context.scaleBy(x: 1.0, y: -1.0)
                context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                
                for image in data.images {
                    context.draw(image.img.precomposed(flipVertical: true), in: image.rect.apply(multiplier: image.multiplier))
                }
            }, scale: 1.0)!
        }
        
        return image
    }
    
    public static func generateNewUrl(data: EditedImageData, selectedRect: NSRect, drawPaintings: Bool = true) -> Signal<URL, NoError> {
        return Signal { subscriber in
            
            if let image = NSImage(contentsOf: data.originalUrl)?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                if selectedRect == NSMakeRect(0, 0, image.size.width, image.size.height) && data.hasntData {
                    subscriber.putNext(data.originalUrl)
                    subscriber.putCompletion()
                } else {
                    if let image = self.makeImage(image, data: data, interface: false, applyPainting: drawPaintings).cropping(to: selectedRect) {
                        return putToTemp(image: NSImage(cgImage: image, size: image.size), compress: true).start(next: { url in
                            subscriber.putNext(URL(fileURLWithPath: url))
                        }, completed: {
                            subscriber.putCompletion()
                        })
                    }
                }
                
                
            }
            subscriber.putCompletion()
            return EmptyDisposable
        } |> runOn(resourcesQueue)
    }
    
}

public final class EditImageControlsArguments {
    public let cancel:()->Void
    public let success: () -> Void
    public let flip: () -> Void
    public let selectionDimensions: (SelectionRectDimensions) -> Void
    public let rotate: () -> Void
    public let draw: ()->Void
    public let getDoneString:()->String?
    public let cutout: (()->Void)?
    public init(cancel:@escaping()->Void, success: @escaping()->Void, flip: @escaping()->Void, selectionDimensions: @escaping(SelectionRectDimensions)->Void, rotate: @escaping() -> Void, draw: @escaping()->Void, getDoneString:@escaping()->String?, cutout: (()->Void)? = nil) {
        self.cancel = cancel
        self.success = success
        self.flip = flip
        self.rotate = rotate
        self.getDoneString = getDoneString
        self.selectionDimensions = selectionDimensions
        self.draw = draw
        self.cutout = cutout
    }
}

public final class EditImageControlsView : View {
    public let cancel = TextButton()
    private let success = TextButton()
    private let controlsContainer = View()
    private let flipper = ImageButton()
    private let draw = ImageButton()
    private let rotate = ImageButton()
    private let dimensions = ImageButton()
    private let cutout = ImageButton()
    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        addSubview(cancel)
        addSubview(success)
        
        addSubview(controlsContainer)
        
        controlsContainer.addSubview(flipper)
        controlsContainer.addSubview(draw)
        controlsContainer.addSubview(rotate)
        controlsContainer.addSubview(dimensions)
        controlsContainer.addSubview(cutout)
        
        controlsContainer.border = [.Left, .Right]
        controlsContainer.borderColor = NSColor.black.withAlphaComponent(0.2)
        backgroundColor = NSColor(0x303030)
        layer?.cornerRadius = 6
    }
    
    fileprivate func updateUserInterface(_ data: EditedImageData, doneString: String?) {
        draw.set(image: NSImage(resource: .iconEditImageDraw).precomposed(NSColor.white.withAlphaComponent(0.8)), for: .Normal)
        flipper.set(image: NSImage(resource: .iconEditImageFlip).precomposed(NSColor.white.withAlphaComponent(0.8)), for: .Normal)
        rotate.set(image: NSImage(resource: .iconEditImageRotate).precomposed(NSColor.white.withAlphaComponent(0.8)), for: .Normal)
        dimensions.set(image: NSImage(resource: .iconEditImageSizes).precomposed(NSColor.white.withAlphaComponent(0.8)), for: .Normal)
        cutout.set(image: NSImage(resource: .iconEditImageCutout).precomposed(NSColor.white.withAlphaComponent(0.8)), for: .Normal)

        draw.set(image: NSImage(resource: .iconEditImageDraw).precomposed(.white), for: .Hover)
        flipper.set(image: NSImage(resource: .iconEditImageFlip).precomposed(.white), for: .Hover)
        rotate.set(image: NSImage(resource: .iconEditImageRotate).precomposed(.white), for: .Hover)
        dimensions.set(image: NSImage(resource: .iconEditImageSizes).precomposed(.white), for: .Hover)
        cutout.set(image: NSImage(resource: .iconEditImageCutout).precomposed(.white), for: .Hover)
        
        draw.appTooltip = "⌘D"
        rotate.appTooltip = "⌘R"
        draw.setAccessibilityLabel(strings().voiceOverCommonDraw)
        rotate.setAccessibilityLabel(strings().voiceOverCommonRotate)
        flipper.setAccessibilityLabel(strings().voiceOverCommonFlip)
        dimensions.setAccessibilityLabel(strings().voiceOverCommonAspectRatio)
        cutout.appTooltip = strings().editImageControlsCutOutObject
        cutout.setAccessibilityLabel(strings().editImageControlsCutOutObject)

        _ = draw.sizeToFit(NSZeroSize, NSMakeSize(50, frame.height), thatFit: true)
        _ = flipper.sizeToFit(NSZeroSize, NSMakeSize(50, frame.height), thatFit: true)
        _ = rotate.sizeToFit(NSZeroSize, NSMakeSize(50, frame.height), thatFit: true)
        _ = dimensions.sizeToFit(NSZeroSize, NSMakeSize(50, frame.height), thatFit: true)
        _ = cutout.sizeToFit(NSZeroSize, NSMakeSize(50, frame.height), thatFit: true)
        
        cancel.set(font: .medium(.title), for: .Normal)
        success.set(font: .medium(.title), for: .Normal)
        
        success.set(color: nightAccentPalette.accent, for: .Normal)
        cancel.set(color: .white, for: .Normal)
        
        cancel.set(text: strings().modalCancel, for: .Normal)
        success.set(text: doneString ?? strings().navigationDone, for: .Normal)
        
        _ = cancel.sizeToFit(NSZeroSize, NSMakeSize(75, frame.height), thatFit: true)
        _ = success.sizeToFit(NSZeroSize, NSMakeSize(75, frame.height), thatFit: true)
        
        flipper.isSelected = data.isHorizontalFlipped
        rotate.isSelected = data.orientation != nil
        dimensions.isSelected = data.dimensions != .none
        draw.isSelected = !data.paintings.isEmpty || !data.entities.isEmpty
    }
    
    public override func layout() {
        super.layout()
        controlsContainer.setFrameSize(rotate.frame.width + flipper.frame.width + draw.frame.width + dimensions.frame.width + (cutout.isHidden ? 0 : cutout.frame.width), rotate.frame.height)
        rotate.setFrameOrigin(NSMakePoint(0, 0))
        flipper.setFrameOrigin(NSMakePoint(rotate.frame.maxX, 0))
        draw.setFrameOrigin(NSMakePoint(flipper.frame.maxX, 0))
        dimensions.setFrameOrigin(NSMakePoint(draw.frame.maxX, 0))
        cutout.setFrameOrigin(NSMakePoint(dimensions.frame.maxX, 0))
        controlsContainer.center()
        
        cancel.centerY()
        success.centerY(x: frame.width - success.frame.width)
    }
    
    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
    }
    
    fileprivate func set(settings: EditControllerSettings, handlers: EditImageControlsArguments) {
        
        success.set(handler: { _ in
            handlers.success()
        }, for: .Click)
        
        cancel.set(handler: { _ in
            handlers.cancel()
        }, for: .Click)
        
        flipper.set(handler: { control in
            handlers.flip()
        }, for: .Click)
        
        rotate.set(handler: { _ in
            handlers.rotate()
        }, for: .Click)
        
        draw.set(handler: { _ in
            handlers.draw()
        }, for: .Click)
        
        cutout.isHidden = handlers.cutout == nil
        cutout.set(handler: { _ in
            handlers.cutout?()
        }, for: .Click)
        
        
        dimensions.set(handler: { control in
            switch settings {
            case .disableSizes:
                break
            case .plain:
                if control.isSelected {
                    handlers.selectionDimensions(.none)
                } else {
                    let items: [ContextMenuItem] = SelectionRectDimensions.all.map { value in
                        return ContextMenuItem(value.description, handler: {
                            handlers.selectionDimensions(value)
                        })
                    }
                    if let event = NSApp.currentEvent {
                        let menu = ContextMenu()
                        for item in items {
                            menu.addItem(item)
                        }
                        let value = AppMenu(menu: menu)
                        value.show(event: event, view: control)
                    }
                }
            }
            
           
        }, for: .Click)
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public class EditImageControls: GenericViewController<EditImageControlsView> {
    public let arguments: EditImageControlsArguments
    private let stateDisposable = MetaDisposable()
    private let stateValue: Signal<EditedImageData, NoError>
    private let settings: EditControllerSettings
    public init(settings:EditControllerSettings, arguments: EditImageControlsArguments, stateValue: Signal<EditedImageData, NoError>) {
        self.arguments = arguments
        self.stateValue = stateValue
        self.settings = settings
        super.init(frame: NSMakeRect(0, 0, arguments.cutout == nil ? 350 : 400, 40))
        bar = .init(height: 0)
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.set(settings: settings, handlers: arguments)
        let string = arguments.getDoneString()
        stateDisposable.set(stateValue.start(next: { [weak self] current in
            self?.genericView.updateUserInterface(current, doneString: string)
        }))
    }
    
    deinit {
        stateDisposable.dispose()
    }
}
