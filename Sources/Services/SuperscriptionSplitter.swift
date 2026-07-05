import Foundation

/// Splits a Psalm-style superscription off the front of a verse 1 string.
///
/// Most public-domain Bible JSON sources (including the WEB) lump Psalm
/// inscriptions like "A Psalm by David." into the body of verse 1. Splitting
/// them out preserves the structural distinction between the inscription and
/// the prayer/lyric that follows.
///
/// **Algorithm.** Walk period-and-space sentence boundaries from the start of
/// the verse. Greedily consume a sentence as part of the inscription as long
/// as it contains any inscription-keyword phrase. Stop at the first sentence
/// that contains none — that sentence (and everything after it) is the verse
/// proper. Returns `nil` for the inscription when no leading inscription
/// pattern is detected, which is the correct outcome for psalms like 1 and 2
/// that have no superscription.
///
/// **Why phrases, not bare words.** Matching "Psalm" or "David" alone would
/// produce false positives in regular verse text. Two-word phrases like
/// "A Psalm" or "By David" are inscription-specific and almost never appear
/// in actual prayer or song content.
enum SuperscriptionSplitter {

    /// Multi-word phrases that mark inscription content. Case-insensitive.
    /// Curated against all 150 Psalms in the WEB; covers ~108 of the 122
    /// that carry an inscription.
    static let inscriptionPhrases: [String] = [
        // Genre tags
        "A Psalm",
        "A Prayer",
        "A Poem",
        "A Song",
        "A meditation",
        "A contemplative psalm",
        "A Maskil",
        "A Miktam",
        "A Shiggaion",
        "Song of Ascents",
        // Performance / liturgical directions
        "Chief Musician",
        "Set to",
        // Authors / attribution
        "By David",
        "By Asaph",
        "By Solomon",
        "By Moses",
        "By Ethan",
        "By Heman",
        "the sons of Korah"
    ]

    /// Returns `(superscription, verseText)`. If no inscription is detected,
    /// `superscription` is `nil` and `verseText` is the original input.
    static func split(verseOneText text: String) -> (superscription: String?, verseText: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (nil, text) }

        // Sentence boundaries on ". " preserve quotes-with-internal-periods
        // (e.g. `Set to "The Death of the Son." A Psalm by David.`) because
        // the literal `". "` requires period-then-space, not period-quote-space.
        let parts = trimmed.components(separatedBy: ". ")
        guard parts.count > 1 else {
            // No sentence boundary inside — either the entire string IS the
            // inscription (unlikely for a real verse), or there's no
            // inscription at all. Bail out and treat as plain verse text.
            return (nil, text)
        }

        var inscriptionParts: [String] = []
        var verseStartIndex: Int = 0

        for (i, sentence) in parts.enumerated() {
            if containsInscriptionKeyword(sentence) {
                inscriptionParts.append(sentence)
                verseStartIndex = i + 1
            } else {
                break
            }
        }

        guard !inscriptionParts.isEmpty, verseStartIndex < parts.count else {
            return (nil, text)
        }

        let inscription = inscriptionParts.joined(separator: ". ") + "."
        let verseText = parts[verseStartIndex...].joined(separator: ". ")
        return (inscription, verseText)
    }

    private static func containsInscriptionKeyword(_ sentence: String) -> Bool {
        let lower = sentence.lowercased()
        return inscriptionPhrases.contains { phrase in
            lower.contains(phrase.lowercased())
        }
    }
}
