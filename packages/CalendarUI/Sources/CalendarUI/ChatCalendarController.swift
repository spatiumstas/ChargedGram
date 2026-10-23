import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox
import TelegramContext
import TelegramMediaUtils
import TelegramTheme

private final class ChatCalendarDayPreview: View {
    private let imageView = TransformImageView()
    private let shadeView = View()

    init(context: any AccountContextProtocol, message: Message) {
        let size = NSMakeSize(36, 36)
        super.init(frame: size.bounds)
        isEventLess = true
        layer?.cornerRadius = size.width / 2
        layer?.masksToBounds = true
        backgroundColor = theme.colors.grayBackground
        imageView.frame = bounds
        shadeView.frame = bounds
        shadeView.isEventLess = true
        shadeView.backgroundColor = NSColor.black.withAlphaComponent(0.25)
        addSubview(imageView)
        addSubview(shadeView)

        let signal: Signal<ImageDataTransformation, NoError>
        let dimensions: NSSize
        let isSpoiler = message.attributes.contains { $0 is MediaSpoilerMessageAttribute }
        if let image = message.media.compactMap({ $0 as? TelegramMediaImage }).first {
            let reference = ImageMediaReference.message(message: MessageReference(message), media: image)
            dimensions = image.representations.last?.dimensions.size ?? size
            if isSpoiler {
                signal = chatSecretPhoto(account: context.account, imageReference: reference, scale: System.backingScale)
            } else {
                signal = chatMessagePhoto(account: context.account, imageReference: reference, toRepresentationSize: NSMakeSize(80, 80), scale: System.backingScale, autoFetchFullSize: true)
            }
        } else if let file = message.media.compactMap({ $0 as? TelegramMediaFile }).first(where: { $0.isVideo }) {
            let reference = FileMediaReference.message(message: MessageReference(message), media: file)
            dimensions = file.dimensions?.size ?? file.previewRepresentations.last?.dimensions.size ?? size
            if isSpoiler {
                signal = chatSecretMessageVideo(account: context.account, fileReference: reference, scale: System.backingScale)
            } else {
                signal = chatMessageVideo(account: context.account, fileReference: reference, scale: System.backingScale)
            }
        } else {
            return
        }
        let animated = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        imageView.animatesAlphaOnFirstTransition = animated
        imageView.setSignal(signal, animate: animated)
        imageView.set(arguments: TransformImageArguments(corners: ImageCorners(radius: size.width / 2), imageSize: dimensions.aspectFilled(size), boundingSize: size, intrinsicInsets: NSEdgeInsets(), resizeMode: .none))
    }

    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class ChatCalendarMedia {
    private let context: any AccountContextProtocol
    private let source: SparseMessageCalendar
    private let disposable = DisposableSet()
    private var messagesByDay: [Int: Message] = [:]

    init(context: any AccountContextProtocol, peerId: PeerId) {
        self.context = context
        self.source = context.engine.messages.sparseMessageCalendar(peerId: peerId, threadId: nil, tag: .photoOrVideo, displayMedia: true)
    }

    func start(updated: @escaping () -> Void) {
        disposable.add((source.state |> deliverOnMainQueue).start(next: { [weak self] state in
            guard let self else { return }
            let calendar = Calendar(identifier: .gregorian)
            var messages: [Int: Message] = [:]
            for entry in state.messagesByDay.values {
                let message = entry.message
                guard !message.containsSecretMedia, message.media.contains(where: { media in
                    return media is TelegramMediaImage || (media as? TelegramMediaFile)?.isVideo == true
                }) else { continue }
                let date = Date(timeIntervalSince1970: TimeInterval(message.timestamp) - self.context.timeDifference)
                let timestamp = Int(calendar.startOfDay(for: date).timeIntervalSince1970)
                if let existing = messages[timestamp], existing.index >= message.index {
                    continue
                }
                messages[timestamp] = message
            }
            self.messagesByDay = messages
            updated()
        }))
        disposable.add((source.isLoadingMore |> distinctUntilChanged |> filter { !$0 } |> deliverOnMainQueue).start(next: { [weak self] _ in
            self?.source.loadMore()
        }))
    }

    func preview(timestamp: Int) -> NSView? {
        guard let message = messagesByDay[timestamp] else { return nil }
        return ChatCalendarDayPreview(context: context, message: message)
    }

    deinit {
        disposable.dispose()
    }
}

public func ChatCalendarController(context: any AccountContextProtocol, peerId: PeerId, current: Date, select: @escaping (Date) -> Void) -> ViewController {
    let media = ChatCalendarMedia(context: context, peerId: peerId)
    let controller = CalendarController(NSMakeRect(0, 0, 300, 300), context.window, current: current, selectHandler: select)
    controller.dayPreview = { timestamp in
        return media.preview(timestamp: timestamp)
    }
    media.start(updated: { [weak controller] in
        controller?.updateDayPreviews()
    })
    return controller
}
