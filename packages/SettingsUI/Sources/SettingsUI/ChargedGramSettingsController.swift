import Foundation
import ChargedGramSettings
import SwiftSignalKit
import InputDataUI
import Localization
import TelegramTheme

private final class Arguments {
    let toggle: (ReferenceWritableKeyPath<ChargedGramSettings, Bool>) -> Void

    init(toggle: @escaping (ReferenceWritableKeyPath<ChargedGramSettings, Bool>) -> Void) {
        self.toggle = toggle
    }
}

private struct State: Equatable {
    var keepChatsUnread: Bool
    var confirmCalls: Bool
    var hidePhoneNumbers: Bool
    var hideContactsTab: Bool
    var showDeletedMessages: Bool
    var reactionsOnHover: Bool
}

private func entries(_ state: State, language: TelegramLocalization, arguments: Arguments) -> [InputDataEntry] {
    func text(_ key: String) -> String {
        return ChargedGramStrings.text(key, languageCode: language.primaryLanguage.languageCode, fallbackLanguageCode: language.secondaryLanguage?.languageCode)
    }
    let rows: [(String, Bool, () -> Void)] = [
        ("KeepChatsUnread", state.keepChatsUnread, { arguments.toggle(\.keepChatsUnread) }),
        ("ConfirmCalls", state.confirmCalls, { arguments.toggle(\.confirmCalls) }),
        ("HidePhoneNumbers", state.hidePhoneNumbers, { arguments.toggle(\.hidePhoneNumbers) }),
        ("HideContactsTab", state.hideContactsTab, { arguments.toggle(\.hideContactsTab) }),
        ("ShowDeletedMessages", state.showDeletedMessages, { arguments.toggle(\.showDeletedMessages) }),
        ("ReactionsOnHover", state.reactionsOnHover, { arguments.toggle(\.reactionsOnHover) })
    ]
    var result: [InputDataEntry] = [.sectionId(0, type: .normal)]
    for (index, row) in rows.enumerated() {
        let sectionId = Int32(index + 1)
        result.append(.general(sectionId: sectionId, index: Int32(index * 2), value: .none, error: nil, identifier: InputDataIdentifier("chargedGram_" + row.0), data: .init(name: text(row.0), color: theme.colors.text, type: .switchable(row.1), viewType: .singleItem, action: row.2)))
        if row.0 == "ConfirmCalls" || row.0 == "HidePhoneNumbers" {
            result.append(.desc(sectionId: sectionId, index: Int32(index * 2 + 1), text: .plain(text(row.0 + "Info")), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        }
        result.append(.sectionId(sectionId, type: .normal))
    }
    return result
}

func ChargedGramSettingsController() -> InputDataController {
    let settings = ChargedGramSettings.shared
    func state() -> State {
        return State(keepChatsUnread: settings.keepChatsUnread, confirmCalls: settings.confirmCalls, hidePhoneNumbers: settings.hidePhoneNumbers, hideContactsTab: settings.hideContactsTab, showDeletedMessages: settings.showDeletedMessages, reactionsOnHover: settings.reactionsOnHover)
    }
    let arguments = Arguments(toggle: { key in
        settings[keyPath: key].toggle()
    })
    let stateSignal = Signal<State, NoError> { subscriber in
        let observer = NotificationCenter.default.addObserver(forName: ChargedGramSettings.didChange, object: nil, queue: nil) { _ in
            subscriber.putNext(state())
        }
        subscriber.putNext(state())
        return ActionDisposable {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    let signal = combineLatest(stateSignal |> distinctUntilChanged, appearanceSignal)
    |> deliverOnPrepareQueue |> map { state, appearance in
        return InputDataSignalValue(entries: entries(state, language: appearance.language, arguments: arguments))
    }
    return InputDataController(dataSignal: signal, title: "ChargedGram", hasDone: false, identifier: "chargedGram")
}
