import Foundation

struct ChatInputDictationDraft {
    let prefix: NSAttributedString
    let suffix: NSAttributedString
    let attributes: [NSAttributedString.Key: Any]

    init(text: NSAttributedString, selection: Range<Int>, excludingAttribute: (NSAttributedString.Key, Any) -> Bool = { _, _ in false }) {
        let length = text.length
        let lower = max(0, min(selection.lowerBound, length))
        let upper = max(lower, min(selection.upperBound, length))
        self.prefix = text.attributedSubstring(from: NSMakeRange(0, lower))
        self.suffix = text.attributedSubstring(from: NSMakeRange(upper, length - upper))
        if lower > 0 {
            self.attributes = text.attributes(at: lower - 1, effectiveRange: nil).filter { !excludingAttribute($0.key, $0.value) }
        } else {
            self.attributes = [:]
        }
    }

    func compose(_ transcript: String) -> (text: NSAttributedString, cursor: Int) {
        let insertion = ChatInputDictationText.insertion(prefix: prefix.string, transcript: transcript, suffix: suffix.string)
        let result = NSMutableAttributedString(attributedString: prefix)
        result.append(NSAttributedString(string: insertion, attributes: attributes))
        let cursor = result.length
        result.append(suffix)
        return (result, cursor)
    }
}

enum ChatInputDictationText {
    private static let opening: Set<Character> = ["(", "[", "{", "«", "“", "‘", "\"", "'", "@", "#", "/"]
    private static let closing: Set<Character> = [".", ",", "!", "?", ";", ":", ")", "]", "}", "»", "”", "’", "…"]
    private static let primaryRegion: [String: String] = [
        "en": "us", "es": "es", "pt": "br", "zh": "cn", "ar": "sa", "uk": "ua", "ja": "jp", "ko": "kr",
        "sv": "se", "da": "dk", "he": "il", "el": "gr", "cs": "cz", "hi": "in", "vi": "vn", "ms": "my",
        "ca": "es", "nb": "no", "yue": "cn", "wuu": "cn", "fa": "ir", "kk": "kz", "et": "ee"
    ]

    static func insertion(prefix: String, transcript: String, suffix: String) -> String {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ""
        }
        var result = trimmed
        if let last = prefix.last, !last.isWhitespace, !opening.contains(last) {
            result = " " + result
        }
        if let first = suffix.first, !first.isWhitespace, !closing.contains(first) {
            result += " "
        }
        return result
    }

    static func join(_ head: String, _ tail: String) -> String {
        guard let last = head.last, let first = tail.first else {
            return head + tail
        }
        if last.isWhitespace || first.isWhitespace || closing.contains(first) || opening.contains(last) {
            return head + tail
        }
        return head + " " + tail
    }

    static func resolveLocale(preferred: [String], supported: [String]) -> String? {
        let normalized = supported.map { (original: $0, key: normalize($0)) }
        for identifier in preferred {
            let key = normalize(identifier)
            if let match = normalized.first(where: { $0.key == key }) {
                return match.original
            }
            let parts = key.split(separator: "-").map(String.init)
            guard let language = parts.first, !language.isEmpty else {
                continue
            }
            let candidates = normalized.filter { $0.key == language || $0.key.hasPrefix(language + "-") }
            if candidates.isEmpty {
                continue
            }
            if parts.count > 1, let region = parts.last, let match = candidates.first(where: { $0.key.hasSuffix("-" + region) }) {
                return match.original
            }
            let primary = primaryRegion[language] ?? language
            if let match = candidates.first(where: { $0.key == language + "-" + primary }) {
                return match.original
            }
            return candidates.map(\.original).sorted().first
        }
        return nil
    }

    static func stablePrefix(previous: String, current: String) -> String {
        let old = Array(previous)
        let new = Array(current)
        var position = 0
        while position < min(old.count, new.count), old[position] == new[position] {
            position += 1
        }
        let splitsWord = position > 0 && !new[position - 1].isWhitespace && (position == new.count || !new[position].isWhitespace)
        if splitsWord {
            while position > 0, !new[position - 1].isWhitespace {
                position -= 1
            }
        }
        return String(new[0 ..< position])
    }

    static func automaticLocales(preferred: [String], supported: [String], limit: Int) -> [String] {
        var result: [String] = []
        var languages: Set<String> = []
        for identifier in preferred {
            guard result.count < limit, let resolved = resolveLocale(preferred: [identifier], supported: supported) else {
                continue
            }
            if languages.insert(languageCode(of: resolved)).inserted {
                result.append(resolved)
            }
        }
        return result
    }

    static func languageCode(of identifier: String) -> String {
        let key = normalize(identifier)
        let language = key.split(separator: "-").first.map(String.init) ?? key
        return language.uppercased()
    }

    static func score(stability: Double, confidence: Double?, priority: Int) -> Double {
        let bonus = priority == 0 ? 0.04 : 0
        if let confidence {
            return stability * 0.5 + confidence * 0.5 + bonus
        }
        return stability + bonus
    }

    private static func normalize(_ identifier: String) -> String {
        let base = identifier.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? identifier
        return base.replacingOccurrences(of: "_", with: "-").lowercased()
    }
}

struct ChatInputDictationStability {
    private var total: Double = 0
    private var samples: Int = 0

    var value: Double {
        return samples == 0 ? 0.5 : total / Double(samples)
    }

    mutating func update(previous: String, current: String) {
        let old = ChatInputDictationStability.words(previous)
        let new = ChatInputDictationStability.words(current)
        let compared = min(old.count - 1, new.count)
        guard compared > 0 else {
            return
        }
        var kept = 0
        while kept < compared, old[kept] == new[kept] {
            kept += 1
        }
        total += Double(kept) / Double(compared)
        samples += 1
    }

    private static func words(_ text: String) -> [String] {
        return text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    }
}
