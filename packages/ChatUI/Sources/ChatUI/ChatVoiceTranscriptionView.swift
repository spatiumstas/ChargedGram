import Cocoa
import TGUIKit
import TelegramCore
import Postbox
import TelegramTheme
import TelegramContext
import Localization

final class ChatVoiceTranscriptionView: View {
    enum Action {
        case edit
        case send
        case cancel
    }

    private static let rightInset: CGFloat = 14
    private static let leftInset: CGFloat = 60
    private static let maxBubbleWidth: CGFloat = 480
    private static let minBubbleWidth: CGFloat = 220
    private static let contentInsets = NSEdgeInsets(top: 7, left: 12, bottom: 7, right: 16)
    private static let markupGap: CGFloat = 4
    private static let ringWidth: CGFloat = 2
    private static let editData = MemoryBuffer(data: "transcription.edit".data(using: .utf8)!)
    private static let sendData = MemoryBuffer(data: "transcription.send".data(using: .utf8)!)
    private static let cancelData = MemoryBuffer(data: "transcription.cancel".data(using: .utf8)!)

    private let context: any AccountContextProtocol

    private let bubbleContainer = View()
    private let bubble = ChatMessageBubbleBackdrop()
    private let textView = TextView()
    private let metaView = TextView()
    private let shimmerHost = CALayer()
    private let shimmer = CAGradientLayer()
    private let shimmerMask = CAShapeLayer()
    private let glowView = ChatVoiceTranscriptionGlowView()
    private let halo = ChatBubbleSliceLayer()
    private let ringMask = ChatBubbleSliceLayer()
    private let ringHost = SimpleLayer()
    private let ring = CAGradientLayer()
    private let markupView = View()
    private var markup: ReplyMarkupNode?
    private var markupWidth: CGFloat = 0

    private var text: String = ""
    private var stableText: String = ""
    private var language: String?
    private var textLayout: TextViewLayout?
    private var metaLayout: TextViewLayout?
    private var isListening = false
    private var level: CGFloat = 0
    private(set) var contentHeight: CGFloat = 0
    private var bubbleSize: NSSize = .zero

    var onAction: ((Action) -> Void)?
    var languageMenu: (() -> ContextMenu?)?
    var gradientRect: (() -> (rect: NSRect, size: NSSize))?

    init(frame frameRect: NSRect, context: any AccountContextProtocol) {
        self.context = context
        super.init(frame: frameRect)
        layer?.masksToBounds = false

        bubbleContainer.layer?.masksToBounds = false
        addSubview(bubbleContainer)

        let glow = glowView.layer!
        glow.masksToBounds = false
        glow.opacity = 0
        halo.shadowOffset = .zero
        halo.shadowRadius = 12
        halo.shadowOpacity = 0.45
        glow.addSublayer(halo)

        if #available(macOS 10.14, *) {
            ring.type = .conic
        }
        ring.startPoint = CGPoint(x: 0.5, y: 0.5)
        ring.endPoint = CGPoint(x: 0.5, y: 0)
        ringHost.addSublayer(ring)
        ringHost.mask = ringMask
        glow.addSublayer(ringHost)

        bubbleContainer.addSubview(glowView)
        bubbleContainer.addSubview(bubble)

        textView.userInteractionEnabled = false
        textView.isSelectable = false
        bubbleContainer.addSubview(textView)

        metaView.userInteractionEnabled = false
        metaView.isSelectable = false
        bubbleContainer.addSubview(metaView)

        shimmer.startPoint = CGPoint(x: 0, y: 0.5)
        shimmer.endPoint = CGPoint(x: 1, y: 0.5)
        shimmer.locations = [0, 0.15, 0.3]
        shimmerHost.mask = shimmerMask
        shimmerHost.addSublayer(shimmer)
        shimmerHost.opacity = 0
        textView.layer?.addSublayer(shimmerHost)

        markupView.layer?.masksToBounds = false
        addSubview(markupView)

        rebuildMarkup()
        updateLocalizationAndTheme(theme: theme)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }

    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = theme as! TelegramPresentationTheme
        let form = messageBubbleImageModern(incoming: false, fillColor: .black, strokeColor: .clear, neighbors: .none)
        bubble.setType(image: form, border: nil, background: theme.icons.chatGradientBubble_outgoing)

        let accent = theme.colors.accent
        halo.data = messageBubbleImageModern(incoming: false, fillColor: accent, strokeColor: .clear, neighbors: .none)
        halo.shadowColor = accent.cgColor
        ringMask.data = ChatVoiceTranscriptionView.outline(form, width: ChatVoiceTranscriptionView.ringWidth)
        ring.colors = [accent.cgColor, accent.lighter(amount: 0.45).cgColor, accent.withAlphaComponent(0.15).cgColor, accent.withAlphaComponent(0.6).cgColor, accent.cgColor]
        shimmer.colors = [NSColor.white.withAlphaComponent(0).cgColor, NSColor.white.withAlphaComponent(0.55).cgColor, NSColor.white.withAlphaComponent(0).cgColor]
        rebuildMarkup()
        relayoutText()
        needsLayout = true
    }

    private func rebuildMarkup() {
        let rows: [ReplyMarkupRow] = [
            ReplyMarkupRow(buttons: [
                ReplyMarkupButton(title: strings().chatTranscriptionEdit, titleWhenForwarded: nil, action: .callback(requiresPassword: false, data: ChatVoiceTranscriptionView.editData), style: nil),
                ReplyMarkupButton(title: strings().chatTranscriptionSend, titleWhenForwarded: nil, action: .callback(requiresPassword: false, data: ChatVoiceTranscriptionView.sendData), style: nil)
            ]),
            ReplyMarkupRow(buttons: [
                ReplyMarkupButton(title: strings().chatTranscriptionCancel, titleWhenForwarded: nil, action: .callback(requiresPassword: false, data: ChatVoiceTranscriptionView.cancelData), style: nil)
            ])
        ]
        let interactions = ReplyMarkupInteractions(context: context, proccess: { [weak self] button, _ in
            guard case let .callback(_, data) = button.action else {
                return
            }
            if data == ChatVoiceTranscriptionView.editData {
                self?.onAction?(.edit)
            } else if data == ChatVoiceTranscriptionView.sendData {
                self?.onAction?(.send)
            } else if data == ChatVoiceTranscriptionView.cancelData {
                self?.onAction?(.cancel)
            }
        })
        let theme = theme
        let node = ReplyMarkupNode(rows, [], interactions, theme, markupView, false, outerCornerRadius: theme.bubbled ? 12 : 0, roundsTopCorners: false)
        node.view = markupView
        markup = node
        markupWidth = 0
        if bubbleSize.width > 0 {
            applyMarkup(width: bubbleSize.width)
        }
    }

    func update(text: String, language: String?, isListening: Bool, width: CGFloat) {
        let previous = self.text
        self.stableText = isListening ? ChatInputDictationText.stablePrefix(previous: previous, current: text) : text
        self.text = text
        self.language = language
        self.isListening = isListening
        relayoutText(width: width)
    }

    private func relayoutText(width: CGFloat? = nil) {
        let theme = theme
        let width = width ?? frame.width
        let insets = ChatVoiceTranscriptionView.contentInsets
        let maxBubble = max(ChatVoiceTranscriptionView.minBubbleWidth, min(ChatVoiceTranscriptionView.maxBubbleWidth, width - ChatVoiceTranscriptionView.leftInset - ChatVoiceTranscriptionView.rightInset))
        let textColor = theme.chat.textColor(false, true)
        let grayColor = theme.chat.grayText(false, true)
        let font = NSFont.normal(theme.fontSize)

        let attributed = NSMutableAttributedString()
        if text.isEmpty {
            _ = attributed.append(string: strings().chatTranscriptionListening, color: grayColor, font: font)
        } else {
            let stableLength = min((stableText as NSString).length, (text as NSString).length)
            _ = attributed.append(string: text, color: textColor, font: font)
            if stableLength < attributed.length {
                attributed.addAttribute(.foregroundColor, value: textColor.withAlphaComponent(0.55), range: NSMakeRange(stableLength, attributed.length - stableLength))
            }
        }
        let layout = TextViewLayout(attributed, alwaysStaticItems: true)
        layout.measure(width: maxBubble - insets.left - insets.right)
        textLayout = layout

        let meta = TextViewLayout(.initialize(string: language ?? "", color: grayColor, font: .normal(.small)), maximumNumberOfLines: 1)
        meta.measure(width: .greatestFiniteMagnitude)
        metaLayout = meta

        let metaWidth = language == nil ? 0 : meta.layoutSize.width + 8
        let lastLine = layout.lines.last?.frame.width ?? layout.layoutSize.width
        var contentWidth = max(layout.layoutSize.width, lastLine + metaWidth)
        var textHeight = layout.layoutSize.height
        if contentWidth > maxBubble - insets.left - insets.right {
            contentWidth = layout.layoutSize.width
            textHeight += meta.layoutSize.height
        }
        let bubbleWidth = max(ChatVoiceTranscriptionView.minBubbleWidth, min(maxBubble, contentWidth + insets.left + insets.right))
        bubbleSize = NSMakeSize(bubbleWidth, textHeight + insets.top + insets.bottom)

        applyMarkup(width: bubbleWidth)

        let markupHeight = markup?.size.height ?? 0
        contentHeight = bubbleSize.height + ChatVoiceTranscriptionView.markupGap + markupHeight
    }

    private func applyMarkup(width: CGFloat) {
        guard let markup, width != markupWidth else {
            return
        }
        markupWidth = width
        markup.measureSize(width)
        markup.redraw()
        markup.layout()
    }

    private static func outline(_ form: (CGImage, NSEdgeInsets), width: CGFloat) -> (CGImage, NSEdgeInsets) {
        let scale = System.backingScale
        let formSize = form.0.backingSize
        let size = NSMakeSize(formSize.width + width * 2, formSize.height + width * 2)
        let formRect = CGRect(x: width, y: width, width: formSize.width, height: formSize.height)
        let image = generateImage(size, contextGenerator: { size, context in
            let bounds = size.bounds
            context.clear(bounds)
            let steps = 24
            for ring in [width / 2, width] {
                for step in 0 ..< steps {
                    let angle = CGFloat(step) * .pi * 2 / CGFloat(steps)
                    context.saveGState()
                    context.clip(to: formRect.offsetBy(dx: cos(angle) * ring, dy: sin(angle) * ring), mask: form.0)
                    context.setFillColor(NSColor.black.cgColor)
                    context.fill(bounds)
                    context.restoreGState()
                }
            }
            context.saveGState()
            context.clip(to: formRect, mask: form.0)
            context.setBlendMode(.copy)
            context.setFillColor(NSColor.clear.cgColor)
            context.fill(bounds)
            context.restoreGState()
        }, scale: scale)!
        let insets = form.1
        return (image, NSEdgeInsetsMake(insets.top + width, insets.left + width, insets.bottom + width, insets.right + width))
    }

    private var reduceMotion: Bool {
        return NSWorkspace.shared.accessibilityDisplayShouldReduceMotion || context.isLite(.animations)
    }

    func setListening(_ listening: Bool, animated: Bool) {
        let glow = glowView.layer!
        let from = CGFloat(glow.presentation()?.opacity ?? glow.opacity)
        glow.opacity = listening ? 1 : 0
        if animated {
            glow.animateAlpha(from: from, to: listening ? 1 : 0, duration: listening ? 0.3 : 0.5)
        }
        if listening {
            if ring.animation(forKey: "rotation") == nil, !reduceMotion {
                let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
                rotation.fromValue = 0
                rotation.toValue = -CGFloat.pi * 2
                rotation.duration = 3.2
                rotation.repeatCount = .infinity
                rotation.isRemovedOnCompletion = false
                ring.add(rotation, forKey: "rotation")
            }
            if shimmer.animation(forKey: "shimmer") == nil, !reduceMotion {
                let animation = CABasicAnimation(keyPath: "locations")
                animation.fromValue = [-0.3, -0.15, 0]
                animation.toValue = [1, 1.15, 1.3]
                animation.duration = 1.4
                animation.repeatCount = .infinity
                animation.isRemovedOnCompletion = false
                shimmer.add(animation, forKey: "shimmer")
            }
            shimmerHost.opacity = 1
        } else {
            shimmerHost.opacity = 0
            if !animated {
                ring.removeAnimation(forKey: "rotation")
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: { [weak self] in
                    guard let self, !self.isListening else {
                        return
                    }
                    self.ring.removeAnimation(forKey: "rotation")
                    self.shimmer.removeAnimation(forKey: "shimmer")
                })
            }
        }
    }

    func updateLevel(_ level: CGFloat) {
        let level = max(0, min(1, level))
        guard abs(level - self.level) > 0.02 else {
            return
        }
        self.level = level
        let opacity = Float(0.35 + level * 0.55)
        let radius = 10 + level * 12
        let opacityAnimation = CABasicAnimation(keyPath: "shadowOpacity")
        opacityAnimation.fromValue = halo.presentation()?.shadowOpacity ?? halo.shadowOpacity
        opacityAnimation.toValue = opacity
        opacityAnimation.duration = 0.12
        let radiusAnimation = CABasicAnimation(keyPath: "shadowRadius")
        radiusAnimation.fromValue = halo.presentation()?.shadowRadius ?? halo.shadowRadius
        radiusAnimation.toValue = radius
        radiusAnimation.duration = 0.12
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        halo.shadowOpacity = opacity
        halo.shadowRadius = radius
        CATransaction.commit()
        halo.add(opacityAnimation, forKey: "shadowOpacity")
        halo.add(radiusAnimation, forKey: "shadowRadius")
    }

    override func layout() {
        super.layout()
        updateLayout(size: frame.size, transition: .immediate)
    }

    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        let insets = ChatVoiceTranscriptionView.contentInsets
        let bubbleFrame = NSMakeRect(size.width - ChatVoiceTranscriptionView.rightInset - bubbleSize.width, 0, bubbleSize.width, bubbleSize.height)
        transition.updateFrame(view: bubbleContainer, frame: bubbleFrame)
        transition.updateFrame(view: glowView, frame: bubbleFrame.size.bounds)
        transition.updateFrame(view: bubble, frame: bubbleFrame.size.bounds)
        bubble.updateLayout(size: bubbleFrame.size, transition: transition)
        if let gradient = gradientRect?(), gradient.size.width > 0, gradient.size.height > 0 {
            let inHost = bubbleContainer.convert(bubbleContainer.bounds, to: superview)
            bubble.update(rect: NSMakeRect(inHost.minX, gradient.size.height - (gradient.rect.height - inHost.minY) - 30, inHost.width, inHost.height), within: gradient.size, transition: .immediate)
        }

        if let textLayout {
            textView.update(textLayout)
        }
        transition.updateFrame(view: textView, frame: NSMakeRect(insets.left, insets.top, textLayout?.layoutSize.width ?? 0, textLayout?.layoutSize.height ?? 0))
        if let metaLayout {
            metaView.update(metaLayout)
        }
        let metaSize = metaLayout?.layoutSize ?? .zero
        transition.updateFrame(view: metaView, frame: NSMakeRect(bubbleFrame.width - insets.right - metaSize.width, bubbleFrame.height - insets.bottom - metaSize.height + 1, metaSize.width, metaSize.height))

        updateGlow(size: bubbleFrame.size, transition: transition)
        updateShimmer()

        let markupHeight = markup?.size.height ?? 0
        transition.updateFrame(view: markupView, frame: NSMakeRect(bubbleFrame.minX, bubbleFrame.maxY + ChatVoiceTranscriptionView.markupGap, bubbleFrame.width, markupHeight))
    }

    private func updateGlow(size: NSSize, transition: ContainedViewLayoutTransition) {
        let rect = size.bounds
        let ringRect = rect.insetBy(dx: -ChatVoiceTranscriptionView.ringWidth, dy: -ChatVoiceTranscriptionView.ringWidth)
        transition.updateFrame(layer: halo, frame: rect)
        transition.updateFrame(layer: ringHost, frame: ringRect)
        transition.updateFrame(layer: ringMask, frame: ringRect.size.bounds)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let side = ceil(sqrt(ringRect.width * ringRect.width + ringRect.height * ringRect.height))
        ring.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        ring.position = CGPoint(x: ringRect.width / 2, y: ringRect.height / 2)
        CATransaction.commit()
    }

    private func updateShimmer() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shimmerHost.frame = textView.bounds
        shimmer.frame = textView.bounds
        shimmerMask.frame = textView.bounds
        let path = CGMutablePath()
        if let textLayout, isListening, !text.isEmpty {
            let stableLength = min((stableText as NSString).length, (text as NSString).length)
            let length = (text as NSString).length - stableLength
            if length > 0 {
                for (rect, _) in textLayout.rects(NSMakeRange(stableLength, length)) {
                    path.addRect(rect)
                }
            }
        }
        shimmerMask.path = path
        CATransaction.commit()
    }

    override func rightMouseDown(with event: NSEvent) {
        if NSPointInRect(convert(event.locationInWindow, from: nil), bubbleContainer.frame), let menu = languageMenu?() {
            AppMenu.show(menu: menu, event: event, for: self)
            return
        }
        super.rightMouseDown(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control), NSPointInRect(convert(event.locationInWindow, from: nil), bubbleContainer.frame), let menu = languageMenu?() {
            AppMenu.show(menu: menu, event: event, for: self)
            return
        }
        super.mouseDown(with: event)
    }

    func animateIn() {
        guard let layer = bubbleContainer.layer, let markupLayer = markupView.layer else {
            return
        }
        let offset = contentHeight + 20
        for layer in [layer, markupLayer] {
            layer.animatePosition(from: NSMakePoint(0, offset), to: .zero, duration: 0.35, timingFunction: .spring, additive: true)
            layer.animateAlpha(from: 0, to: 1, duration: 0.2)
        }
        layer.animateScaleSpring(from: 0.85, to: 1, duration: 0.4, bounce: true)
    }

    func animateOut(completion: @escaping () -> Void) {
        guard let layer = self.layer else {
            completion()
            return
        }
        layer.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { _ in
            completion()
        })
        bubbleContainer.layer?.animateScaleSpring(from: 1, to: 0.85, duration: 0.25, removeOnCompletion: false, bounce: false)
    }
}

private final class ChatVoiceTranscriptionGlowView: NSView {
    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = false
        layer?.disableActions()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
}
