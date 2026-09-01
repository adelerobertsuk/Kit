import Foundation

/// A fast, on-device tidy pass for a single spoken turn — run once, the moment a
/// listen burst ends, before the turn reaches ConversationManager and gets written
/// to disk. Deterministic string work only: no network, no model, no measurable
/// latency. The end-of-session GeminiClient summary is untouched and still reads
/// the archived turns.
///
/// Deliberately conservative. It clears the mechanical debris of talking while
/// moving — filler sounds, stutter-repeats, missing capitals and stops — and
/// nothing else. It does not rephrase, reorder, trim tangents, or "improve" the
/// words. Diane's rule still holds: write it down, just write it down legibly.
/// The verbatim transcript is kept alongside the tidied one (JournalEntry.rawText).
enum TranscriptCleaner {

    /// Whole-word filler sounds, dropped wherever they land. Kept tight on
    /// purpose — "like", "you know", "I mean" carry meaning often enough that
    /// cutting them crosses from tidying into editing.
    private static let fillers: Set<String> = [
        "um", "umm", "uh", "uhh", "uhm", "erm", "err", "hmm", "hmmm", "mm", "mmm"
    ]

    /// Function words prone to stutter-doubling on a walk ("to to the shop").
    /// Only these collapse on repeat — "very very" or "no no" is real speech
    /// and stays.
    private static let stutterProne: Set<String> = [
        "the", "a", "an", "i", "and", "to", "it", "that", "is", "was", "in",
        "of", "on", "you", "we", "he", "she", "they", "but", "so", "my"
    ]

    private static let trailingPunctuation = CharacterSet(charactersIn: ",.!?;:")

    static func clean(_ input: String) -> String {
        var text = input
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }

        text = stripFillers(from: text)
        text = collapseStutters(in: text)
        text = normalisePunctuationSpacing(in: text)
        text = fixFirstPersonI(in: text)
        text = sentenceCase(text)
        text = ensureTerminalStop(text)

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Steps

    private static func words(_ text: String) -> [Substring] {
        text.split(separator: " ", omittingEmptySubsequences: true)
    }

    private static func bareWord(_ token: Substring) -> String {
        token.lowercased().trimmingCharacters(in: trailingPunctuation)
    }

    private static func stripFillers(from text: String) -> String {
        words(text)
            .filter { !fillers.contains(bareWord($0)) }
            .joined(separator: " ")
    }

    private static func collapseStutters(in text: String) -> String {
        var result: [Substring] = []
        for token in words(text) {
            let bare = bareWord(token)
            if let last = result.last, bareWord(last) == bare, stutterProne.contains(bare) {
                continue
            }
            result.append(token)
        }
        return result.joined(separator: " ")
    }

    private static func normalisePunctuationSpacing(in text: String) -> String {
        var t = text
        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\s+([,.!?;:])", with: "$1", options: .regularExpression)
        t = t.replacingOccurrences(of: "([,.!?;:])(?=\\S)", with: "$1 ", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespaces)
    }

    private static func fixFirstPersonI(in text: String) -> String {
        var t = text.replacingOccurrences(of: "\\bi\\b", with: "I", options: .regularExpression)
        t = t.replacingOccurrences(
            of: "\\bi(['’](m|ll|ve|d|re|s)\\b)",
            with: "I$1",
            options: [.regularExpression, .caseInsensitive]
        )
        return t
    }

    private static func sentenceCase(_ text: String) -> String {
        var chars = Array(text)
        var capitaliseNext = true
        for i in chars.indices {
            let c = chars[i]
            if capitaliseNext, c.isLetter {
                chars[i] = Character(c.uppercased())
                capitaliseNext = false
            } else if ".!?".contains(c) {
                capitaliseNext = true
            } else if c != " ", c != "\"", c != "'", c != "’" {
                capitaliseNext = false
            }
        }
        return String(chars)
    }

    private static func ensureTerminalStop(_ text: String) -> String {
        guard let last = text.last else { return text }
        return ".!?…".contains(last) ? text : text + "."
    }
}
