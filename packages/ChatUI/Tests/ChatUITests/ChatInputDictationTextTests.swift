import XCTest
@testable import ChatUI

final class ChatInputDictationTextTests: XCTestCase {
    func testInsertionIntoEmptyInput() {
        XCTAssertEqual(ChatInputDictationText.insertion(prefix: "", transcript: "Hello world", suffix: ""), "Hello world")
    }

    func testInsertionTrimsTranscript() {
        XCTAssertEqual(ChatInputDictationText.insertion(prefix: "", transcript: "  Hello \n", suffix: ""), "Hello")
    }

    func testEmptyTranscriptInsertsNothing() {
        XCTAssertEqual(ChatInputDictationText.insertion(prefix: "Hi", transcript: "   ", suffix: " there"), "")
    }

    func testInsertionAddsLeadingSpaceAfterWord() {
        XCTAssertEqual(ChatInputDictationText.insertion(prefix: "Hi", transcript: "there", suffix: ""), " there")
    }

    func testInsertionKeepsExistingWhitespace() {
        XCTAssertEqual(ChatInputDictationText.insertion(prefix: "Hi ", transcript: "there", suffix: ""), "there")
        XCTAssertEqual(ChatInputDictationText.insertion(prefix: "Hi\n", transcript: "there", suffix: ""), "there")
    }

    func testInsertionAfterOpeningBracket() {
        XCTAssertEqual(ChatInputDictationText.insertion(prefix: "note (", transcript: "later", suffix: ")"), "later")
    }

    func testInsertionAddsTrailingSpaceBeforeWord() {
        XCTAssertEqual(ChatInputDictationText.insertion(prefix: "", transcript: "Hello", suffix: "world"), "Hello ")
    }

    func testInsertionNoTrailingSpaceBeforePunctuation() {
        XCTAssertEqual(ChatInputDictationText.insertion(prefix: "Say", transcript: "hello", suffix: ", friend"), " hello")
    }

    func testJoin() {
        XCTAssertEqual(ChatInputDictationText.join("", "Hello"), "Hello")
        XCTAssertEqual(ChatInputDictationText.join("Hello.", "How are you"), "Hello. How are you")
        XCTAssertEqual(ChatInputDictationText.join("Hello. ", "How"), "Hello. How")
        XCTAssertEqual(ChatInputDictationText.join("Hello", "?"), "Hello?")
        XCTAssertEqual(ChatInputDictationText.join("Hello", ""), "Hello")
    }

    func testDraftReplacesPartialAtCursor() {
        let draft = ChatInputDictationDraft(text: NSAttributedString(string: "Hello world"), selection: 5 ..< 5)
        let first = draft.compose("big")
        XCTAssertEqual(first.text.string, "Hello big world")
        XCTAssertEqual(first.cursor, 9)
        let second = draft.compose("big blue")
        XCTAssertEqual(second.text.string, "Hello big blue world")
        XCTAssertEqual(second.cursor, 14)
    }

    func testDraftReplacesSelection() {
        let draft = ChatInputDictationDraft(text: NSAttributedString(string: "Hello there friend"), selection: 6 ..< 11)
        let result = draft.compose("my")
        XCTAssertEqual(result.text.string, "Hello my friend")
        XCTAssertEqual(result.cursor, 8)
    }

    func testDraftEmptyTranscriptRestoresText() {
        let draft = ChatInputDictationDraft(text: NSAttributedString(string: "Hello"), selection: 5 ..< 5)
        let result = draft.compose("")
        XCTAssertEqual(result.text.string, "Hello")
        XCTAssertEqual(result.cursor, 5)
    }

    func testDraftClampsOutOfRangeSelection() {
        let draft = ChatInputDictationDraft(text: NSAttributedString(string: "Hi"), selection: 10 ..< 12)
        let result = draft.compose("there")
        XCTAssertEqual(result.text.string, "Hi there")
        XCTAssertEqual(result.cursor, 8)
    }

    func testDraftInheritsAttributesBeforeCursor() {
        let key = NSAttributedString.Key("test.bold")
        let skipped = NSAttributedString.Key("test.emoji")
        let text = NSMutableAttributedString(string: "Hello")
        text.addAttributes([key: true, skipped: true], range: NSMakeRange(0, 5))
        let draft = ChatInputDictationDraft(text: text, selection: 5 ..< 5, excludingAttribute: { name, _ in name == skipped })
        let result = draft.compose("there")
        XCTAssertNotNil(result.text.attribute(key, at: 7, effectiveRange: nil))
        XCTAssertNil(result.text.attribute(skipped, at: 7, effectiveRange: nil))
    }

    func testResolveLocaleExactMatch() {
        XCTAssertEqual(ChatInputDictationText.resolveLocale(preferred: ["en-US"], supported: ["en_GB", "en_US"]), "en_US")
    }

    func testResolveLocaleRegionFromLanguage() {
        XCTAssertEqual(ChatInputDictationText.resolveLocale(preferred: ["ru-US"], supported: ["en_US", "ru_RU"]), "ru_RU")
        XCTAssertEqual(ChatInputDictationText.resolveLocale(preferred: ["en-RU"], supported: ["en_AU", "en_GB", "en_US"]), "en_US")
        XCTAssertEqual(ChatInputDictationText.resolveLocale(preferred: ["de-CH"], supported: ["de_AT", "de_CH", "de_DE"]), "de_CH")
        XCTAssertEqual(ChatInputDictationText.resolveLocale(preferred: ["en-RU", "ru_RU"], supported: ["en_US", "ru_RU"]), "en_US")
        XCTAssertEqual(ChatInputDictationText.resolveLocale(preferred: ["ru_RU@rg=dezzzz"], supported: ["en_US", "ru_RU"]), "ru_RU")
    }

    func testResolveLocaleFallsBackToNextPreference() {
        XCTAssertEqual(ChatInputDictationText.resolveLocale(preferred: ["xx-YY", "fr_FR"], supported: ["fr-CA", "fr-FR"]), "fr-FR")
    }

    func testResolveLocaleUnsupported() {
        XCTAssertNil(ChatInputDictationText.resolveLocale(preferred: ["xx-YY"], supported: ["en_US"]))
        XCTAssertNil(ChatInputDictationText.resolveLocale(preferred: [], supported: ["en_US"]))
    }

    func testAutomaticLocalesUseDistinctPreferredLanguages() {
        let supported = ["en_US", "en_GB", "ru_RU", "de_DE"]
        XCTAssertEqual(ChatInputDictationText.automaticLocales(preferred: ["ru-RU", "en-RU", "en-GB", "ru"], supported: supported, limit: 4), ["ru_RU", "en_US"])
        XCTAssertEqual(ChatInputDictationText.automaticLocales(preferred: ["en-GB", "ru-RU", "de-DE"], supported: supported, limit: 2), ["en_GB", "ru_RU"])
        XCTAssertEqual(ChatInputDictationText.automaticLocales(preferred: ["xx"], supported: supported, limit: 2), [])
    }

    func testLanguageCode() {
        XCTAssertEqual(ChatInputDictationText.languageCode(of: "ru_RU"), "RU")
        XCTAssertEqual(ChatInputDictationText.languageCode(of: "en-US@rg=gbzzzz"), "EN")
        XCTAssertEqual(ChatInputDictationText.languageCode(of: "zh-Hant-TW"), "ZH")
    }

    func testStabilityPrefersAppendingTranscripts() {
        var stable = ChatInputDictationStability()
        stable.update(previous: "", current: "Hello")
        stable.update(previous: "Hello", current: "Hello how")
        stable.update(previous: "Hello how", current: "Hello how are")
        stable.update(previous: "Hello how are", current: "Hello how are you")
        var unstable = ChatInputDictationStability()
        unstable.update(previous: "Privet", current: "Pre vet cock")
        unstable.update(previous: "Pre vet cock", current: "Previous cake ago")
        unstable.update(previous: "Previous cake ago", current: "Pretty cat a go")
        XCTAssertEqual(stable.value, 1, accuracy: 0.0001)
        XCTAssertLessThan(unstable.value, 0.5)
        XCTAssertEqual(ChatInputDictationStability().value, 0.5, accuracy: 0.0001)
    }

    func testScoreUsesConfidenceAndPriority() {
        XCTAssertGreaterThan(ChatInputDictationText.score(stability: 0.9, confidence: 0.9, priority: 1), ChatInputDictationText.score(stability: 0.9, confidence: 0.3, priority: 0))
        XCTAssertGreaterThan(ChatInputDictationText.score(stability: 0.8, confidence: nil, priority: 0), ChatInputDictationText.score(stability: 0.8, confidence: nil, priority: 1))
    }

    func testStablePrefixKeepsWholeWordsOnly() {
        XCTAssertEqual(ChatInputDictationText.stablePrefix(previous: "Hello wor", current: "Hello world how"), "Hello ")
        XCTAssertEqual(ChatInputDictationText.stablePrefix(previous: "Hello world", current: "Hello world"), "Hello ")
        XCTAssertEqual(ChatInputDictationText.stablePrefix(previous: "Hello world ", current: "Hello world how"), "Hello world ")
        XCTAssertEqual(ChatInputDictationText.stablePrefix(previous: "", current: "Hello"), "")
        XCTAssertEqual(ChatInputDictationText.stablePrefix(previous: "Privet kak", current: "Привет как"), "")
    }
}
