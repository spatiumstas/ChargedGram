import Cocoa
import TGUIKit
import SwiftSignalKit
import InputView
import AlertsUI
import Localization
import SystemPermissions
import TelegramTheme

protocol ChatVoiceTranscriptionHost: AnyObject {
    func setTranscriptionView(_ view: ChatVoiceTranscriptionView?, animated: Bool)
    func transcriptionLayoutDidChange(animated: Bool)
    var transcriptionWidth: CGFloat { get }
    func transcriptionGradient() -> (rect: NSRect, size: NSSize)
}

final class ChatVoiceTranscription {
    enum Phase: Equatable {
        case idle
        case preparing
        case listening
        case finishing
        case finished
    }

    private weak var chatInteraction: ChatInteraction?
    private weak var host: ChatVoiceTranscriptionHost?
    private var view: ChatVoiceTranscriptionView?
    private var engine: ChatDictationEngine?
    private let permissionDisposable = MetaDisposable()
    private var token: Int = 0
    private var prefix: String = ""
    private var current: String = ""
    private var language: String?
    private var pendingAction: ChatVoiceTranscriptionView.Action?

    private(set) var phase: Phase = .idle

    init(chatInteraction: ChatInteraction, host: ChatVoiceTranscriptionHost) {
        self.chatInteraction = chatInteraction
        self.host = host
    }

    deinit {
        permissionDisposable.dispose()
        engine?.cancel()
    }

    static var isSupported: Bool {
        #if DEBUG && !BETA
        if #available(macOS 10.15, *) {
            return true
        }
        #endif
        return false
    }

    var isActive: Bool {
        return phase != .idle
    }

    private var text: String {
        return ChatInputDictationText.join(prefix, current)
    }

    private var window: Window? {
        return chatInteraction?.interactionContext.window
    }

    func start() {
        guard Self.isSupported, #available(macOS 10.15, *) else {
            return
        }
        if phase != .idle {
            dismiss(animated: false)
        }
        token += 1
        let token = self.token
        prefix = ""
        current = ""
        language = nil
        pendingAction = nil
        phase = .preparing
        showView()

        permissionDisposable.set(requestSpeechRecognitionPermission().start(next: { [weak self] granted in
            guard let self, self.token == token, self.phase == .preparing else {
                return
            }
            if granted {
                self.createEngine(token: token)
            } else {
                self.fail(.speechDenied)
            }
        }))
    }

    @available(macOS 10.15, *)
    private func createEngine(token: Int) {
        let requiresOnDevice = chatInteraction?.presentation.peer?.isSecretChat == true
        ChatDictationEngineFactory.make(selection: ChatInputDictationLanguage.selected, requiresOnDevice: requiresOnDevice, completion: { [weak self] result in
            guard let self, self.token == token, self.phase == .preparing else {
                if case let .success(engine) = result {
                    engine.cancel()
                }
                return
            }
            switch result {
            case let .success(engine):
                self.begin(with: engine, token: token)
            case let .failure(error):
                self.fail(error)
            }
        })
    }

    private func begin(with engine: ChatDictationEngine, token: Int) {
        engine.onTranscript = { [weak self] text in
            guard let self, self.token == token else {
                return
            }
            self.current = text
            self.refresh(animated: true)
        }
        engine.onLanguage = { [weak self] language in
            guard let self, self.token == token else {
                return
            }
            self.language = language
            self.refresh(animated: true)
        }
        engine.onLevel = { [weak self] level in
            guard let self, self.token == token, self.phase == .listening else {
                return
            }
            self.view?.updateLevel(level)
        }
        engine.onFinish = { [weak self] error in
            guard let self, self.token == token else {
                return
            }
            self.engineFinished(error)
        }
        self.engine = engine
        do {
            try engine.start()
        } catch {
            self.engine = nil
            engine.cancel()
            fail(error as? ChatDictationError ?? .failed)
            return
        }
        phase = .listening
        view?.setListening(true, animated: true)
        refresh(animated: true)
    }

    private func engineFinished(_ error: ChatDictationError?) {
        let wasListening = phase == .listening
        engine = nil
        if let error, wasListening, text.isEmpty {
            fail(error)
            return
        }
        phase = .finished
        view?.setListening(false, animated: true)
        refresh(animated: true)
        if let action = pendingAction {
            pendingAction = nil
            complete(action)
        } else if text.isEmpty {
            dismiss(animated: true)
        }
    }

    func recordingStopped() {
        switch phase {
        case .preparing:
            token += 1
            permissionDisposable.set(nil)
            phase = .finished
            view?.setListening(false, animated: true)
            if let action = pendingAction {
                pendingAction = nil
                complete(action)
            } else {
                dismiss(animated: true)
            }
        case .listening:
            phase = .finishing
            view?.setListening(false, animated: true)
            refresh(animated: true)
            engine?.stop()
        case .idle, .finishing, .finished:
            break
        }
    }

    func perform(_ action: ChatVoiceTranscriptionView.Action) {
        switch action {
        case .cancel:
            discardRecording()
            dismiss(animated: true)
        case .edit, .send:
            discardRecording()
            switch phase {
            case .preparing, .listening:
                pendingAction = action
                recordingStopped()
            case .finishing:
                pendingAction = action
            case .finished:
                complete(action)
            case .idle:
                break
            }
        }
    }

    private func complete(_ action: ChatVoiceTranscriptionView.Action) {
        let text = self.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let chatInteraction else {
            dismiss(animated: false)
            return
        }
        switch action {
        case .edit:
            if !text.isEmpty {
                let input = chatInteraction.presentation.effectiveInput
                let existing = input.inputText
                let merged = existing.isEmpty ? text : ChatInputDictationText.join(existing, text)
                let state = ChatTextInputState(inputText: merged, selectionRange: merged.length ..< merged.length, attributes: input.attributes)
                chatInteraction.update({ $0.withUpdatedEffectiveInputState(state) })
                chatInteraction.focusInputField()
            }
            dismiss(animated: true)
        case .send:
            if !text.isEmpty {
                chatInteraction.sendPlainText(text)
            }
            dismiss(animated: true)
        case .cancel:
            dismiss(animated: true)
        }
    }

    private func discardRecording() {
        if let chatInteraction, let recorder = chatInteraction.presentation.recordingState, !recorder.isCancelled {
            recorder.discard(from: chatInteraction)
        }
    }

    func dismiss(animated: Bool) {
        token += 1
        permissionDisposable.set(nil)
        engine?.cancel()
        engine = nil
        pendingAction = nil
        phase = .idle
        prefix = ""
        current = ""
        if view != nil {
            view = nil
            host?.setTranscriptionView(nil, animated: animated)
        }
    }

    private func fail(_ error: ChatDictationError) {
        discardRecording()
        dismiss(animated: true)
        showError(error)
    }

    private func showView() {
        guard let host, let chatInteraction else {
            return
        }
        let view = ChatVoiceTranscriptionView(frame: NSMakeRect(0, 0, host.transcriptionWidth, 0), context: chatInteraction.interactionContext)
        view.onAction = { [weak self] action in
            self?.perform(action)
        }
        view.languageMenu = { [weak self] in
            return self?.languageMenu()
        }
        view.gradientRect = { [weak host] in
            return host?.transcriptionGradient() ?? (.zero, .zero)
        }
        view.update(text: text, language: language, isListening: true, width: host.transcriptionWidth)
        self.view = view
        host.setTranscriptionView(view, animated: true)
    }

    private func refresh(animated: Bool) {
        guard let view, let host else {
            return
        }
        let listening = phase == .listening || phase == .preparing
        let previousHeight = view.contentHeight
        view.update(text: text, language: language, isListening: listening, width: host.transcriptionWidth)
        if previousHeight != view.contentHeight {
            host.transcriptionLayoutDidChange(animated: animated)
        } else {
            view.updateLayout(size: view.frame.size, transition: .immediate)
        }
    }

    private func restartForLanguageChange() {
        guard #available(macOS 10.15, *), phase == .listening || phase == .preparing else {
            return
        }
        prefix = text
        current = ""
        language = nil
        engine?.cancel()
        engine = nil
        token += 1
        phase = .preparing
        createEngine(token: token)
    }

    private func showError(_ error: ChatDictationError) {
        guard let window = self.window else {
            return
        }
        switch error {
        case .microphoneDenied, .speechDenied:
            let information = error == .microphoneDenied ? strings().chatInputDictationErrorMicrophone : strings().chatInputDictationErrorSpeech
            verifyAlert_button(for: window, information: information, ok: strings().modalOK, cancel: "", option: strings().requestAccesErrorConirmSettings, successHandler: { result in
                switch result {
                case .thrid:
                    openSystemSettings(error == .microphoneDenied ? .microphone : .speechRecognition)
                default:
                    break
                }
            })
        case .unsupportedLanguage:
            alert(for: window, info: strings().chatInputDictationErrorLanguage)
        case .noInputDevice:
            alert(for: window, info: strings().chatInputDictationErrorNoInput)
        case .unavailable, .failed:
            alert(for: window, info: strings().chatInputDictationErrorUnavailable)
        }
    }

    func languageMenu() -> ContextMenu? {
        guard #available(macOS 10.15, *) else {
            return nil
        }
        let selected = ChatInputDictationLanguage.selected
        let supported = ChatDictationEngineFactory.supportedIdentifiers
        let preferred = ChatInputDictationText.automaticLocales(preferred: ChatDictationEngineFactory.automaticPreferences, supported: supported, limit: .max)
        let current = Locale.current
        let name: (String) -> String = { identifier in
            return current.localizedString(forIdentifier: identifier) ?? identifier
        }
        let others = supported.filter { !preferred.contains($0) }.sorted { name($0).localizedCaseInsensitiveCompare(name($1)) == .orderedAscending }

        let choose: (String?) -> Void = { [weak self] identifier in
            guard ChatInputDictationLanguage.selected != identifier else {
                return
            }
            ChatInputDictationLanguage.selected = identifier
            self?.restartForLanguageChange()
        }

        let menu = ContextMenu()
        menu.addItem(ContextMenuItem(strings().chatInputDictationLanguageAutomatic, handler: {
            choose(nil)
        }, state: selected == nil ? .on : nil))
        let item: (String) -> ContextMenuItem = { identifier in
            return ContextMenuItem(name(identifier), handler: {
                choose(identifier)
            }, state: selected == identifier ? .on : nil)
        }
        if !preferred.isEmpty {
            menu.addItem(ContextSeparatorItem())
            for identifier in preferred {
                menu.addItem(item(identifier))
            }
        }
        if !others.isEmpty {
            menu.addItem(ContextSeparatorItem())
            for identifier in others {
                menu.addItem(item(identifier))
            }
        }
        return menu
    }
}

enum ChatInputDictationLanguage {
    private static let key = "kChatInputDictationLanguage"

    static var selected: String? {
        get {
            return UserDefaults.standard.string(forKey: key)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
}
