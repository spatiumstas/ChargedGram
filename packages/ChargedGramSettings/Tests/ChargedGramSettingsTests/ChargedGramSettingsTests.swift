import Foundation
import XCTest
@testable import ChargedGramSettings

private final class SettingsFixture {
    let suiteName = "ChargedGramSettingsTests.\(UUID().uuidString)"
    let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

final class ChargedGramSettingsTests: XCTestCase {
    func testDisabledByDefault() {
        let fixture = SettingsFixture()
        let settings = ChargedGramSettings(defaults: fixture.defaults)
        XCTAssertFalse(settings.keepChatsUnread)
        XCTAssertFalse(settings.confirmCalls)
        XCTAssertFalse(settings.hidePhoneNumbers)
    }

    func testRetainsExistingUnreadPreference() {
        let fixture = SettingsFixture()
        fixture.defaults.set(true, forKey: "mod.keepChatsUnread")
        XCTAssertTrue(ChargedGramSettings(defaults: fixture.defaults).keepChatsUnread)
    }

    func testPrivacyPreferencesPersistIndependently() {
        let fixture = SettingsFixture()
        let settings = ChargedGramSettings(defaults: fixture.defaults)
        settings.confirmCalls = true
        settings.hidePhoneNumbers = true
        let restored = ChargedGramSettings(defaults: UserDefaults(suiteName: fixture.suiteName)!)
        XCTAssertTrue(restored.confirmCalls)
        XCTAssertTrue(restored.hidePhoneNumbers)
        XCTAssertFalse(restored.keepChatsUnread)
        restored.confirmCalls = false
        XCTAssertFalse(settings.confirmCalls)
        XCTAssertTrue(settings.hidePhoneNumbers)
    }

    func testPersistsEnablingAndDisabling() {
        let fixture = SettingsFixture()
        let settings = ChargedGramSettings(defaults: fixture.defaults)
        settings.keepChatsUnread = true
        let restored = ChargedGramSettings(defaults: UserDefaults(suiteName: fixture.suiteName)!)
        XCTAssertTrue(restored.keepChatsUnread)
        restored.keepChatsUnread = false
        XCTAssertFalse(settings.keepChatsUnread)
    }

    func testNotifiesOnlyWhenValueChangesAndAfterSaving() {
        let fixture = SettingsFixture()
        let center = NotificationCenter()
        let settings = ChargedGramSettings(defaults: fixture.defaults, notificationCenter: center)
        var values: [Bool] = []
        let observer = center.addObserver(forName: ChargedGramSettings.didChange, object: nil, queue: nil) { notification in
            XCTAssertTrue(notification.object as? ChargedGramSettings === settings)
            values.append(settings.keepChatsUnread)
        }
        defer { center.removeObserver(observer) }

        settings.keepChatsUnread = false
        settings.keepChatsUnread = true
        settings.keepChatsUnread = true
        settings.keepChatsUnread = false

        XCTAssertEqual(values, [true, false])
    }

    func testPrivacyChangesNotifyAfterSaving() {
        let fixture = SettingsFixture()
        let center = NotificationCenter()
        let settings = ChargedGramSettings(defaults: fixture.defaults, notificationCenter: center)
        var values: [[Bool]] = []
        let observer = center.addObserver(forName: ChargedGramSettings.didChange, object: nil, queue: nil) { _ in
            values.append([settings.confirmCalls, settings.hidePhoneNumbers])
        }
        defer { center.removeObserver(observer) }
        settings.confirmCalls = true
        settings.confirmCalls = true
        settings.hidePhoneNumbers = true
        settings.hidePhoneNumbers = false
        XCTAssertEqual(values, [[true, false], [true, true], [true, false]])
    }

    func testTranslationsAndLanguageFallback() {
        let keys = ["KeepChatsUnread", "KeepChatsUnreadInfo", "ConfirmCalls", "ConfirmCallsInfo", "HidePhoneNumbers", "HidePhoneNumbersInfo", "ConfirmCallTitle", "ConfirmVoiceCall", "ConfirmVideoCall", "Call"]
        for key in keys {
            let english = ChargedGramStrings.text(key, languageCode: "en")
            let russian = ChargedGramStrings.text(key, languageCode: "ru")
            if key != "Call" {
                XCTAssertNotEqual(english, key)
            }
            XCTAssertNotEqual(russian, key)
            XCTAssertNotEqual(english, russian)
            XCTAssertEqual(ChargedGramStrings.text(key, languageCode: "ru-RU"), russian)
            XCTAssertEqual(ChargedGramStrings.text(key, languageCode: "custom", fallbackLanguageCode: "ru"), russian)
            XCTAssertEqual(ChargedGramStrings.text(key, languageCode: "de"), english)
        }
        XCTAssertEqual(String(format: ChargedGramStrings.text("ConfirmVoiceCall", languageCode: "ru"), "Alice"), "Позвонить Alice?")
    }
}
