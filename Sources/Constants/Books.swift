import Foundation

enum Testament: String, Codable, Hashable {
    case old = "OT"
    case new = "NT"
}

/// Canonical Protestant Bible books (66), addressed by USFM 3-letter abbreviation.
/// The abbreviation is the stable internal identifier; `displayName` matches the
/// JSON key used by the bundled WEB and most public Bible JSON sources.
enum Book: String, CaseIterable, Codable, Hashable, Identifiable {
    // Old Testament — Pentateuch
    case GEN, EXO, LEV, NUM, DEU
    // OT — Historical
    case JOS, JDG, RUT, SA1 = "1SA", SA2 = "2SA", KI1 = "1KI", KI2 = "2KI"
    case CH1 = "1CH", CH2 = "2CH", EZR, NEH, EST
    // OT — Wisdom & Poetry
    case JOB, PSA, PRO, ECC, SNG
    // OT — Major Prophets
    case ISA, JER, LAM, EZK, DAN
    // OT — Minor Prophets
    case HOS, JOL, AMO, OBA, JON, MIC, NAM, HAB, ZEP, HAG, ZEC, MAL
    // New Testament — Gospels & Acts
    case MAT, MRK, LUK, JHN, ACT
    // NT — Pauline Epistles
    case ROM, CO1 = "1CO", CO2 = "2CO", GAL, EPH, PHP, COL
    case TH1 = "1TH", TH2 = "2TH", TI1 = "1TI", TI2 = "2TI", TIT, PHM
    // NT — General Epistles
    case HEB, JAS, PE1 = "1PE", PE2 = "2PE", JN1 = "1JN", JN2 = "2JN", JN3 = "3JN", JUD
    // NT — Apocalypse
    case REV

    var id: String { rawValue }

    var abbreviation: String { rawValue }

    var testament: Testament {
        switch self {
        case .GEN, .EXO, .LEV, .NUM, .DEU,
             .JOS, .JDG, .RUT, .SA1, .SA2, .KI1, .KI2,
             .CH1, .CH2, .EZR, .NEH, .EST,
             .JOB, .PSA, .PRO, .ECC, .SNG,
             .ISA, .JER, .LAM, .EZK, .DAN,
             .HOS, .JOL, .AMO, .OBA, .JON, .MIC,
             .NAM, .HAB, .ZEP, .HAG, .ZEC, .MAL:
            return .old
        default:
            return .new
        }
    }

    /// English display name. Matches the JSON key used by the bundled WEB and
    /// most public-domain Bible JSON sources (e.g. "1 Samuel", "Song of Solomon").
    var displayName: String {
        switch self {
        case .GEN: return "Genesis"
        case .EXO: return "Exodus"
        case .LEV: return "Leviticus"
        case .NUM: return "Numbers"
        case .DEU: return "Deuteronomy"
        case .JOS: return "Joshua"
        case .JDG: return "Judges"
        case .RUT: return "Ruth"
        case .SA1: return "1 Samuel"
        case .SA2: return "2 Samuel"
        case .KI1: return "1 Kings"
        case .KI2: return "2 Kings"
        case .CH1: return "1 Chronicles"
        case .CH2: return "2 Chronicles"
        case .EZR: return "Ezra"
        case .NEH: return "Nehemiah"
        case .EST: return "Esther"
        case .JOB: return "Job"
        case .PSA: return "Psalms"
        case .PRO: return "Proverbs"
        case .ECC: return "Ecclesiastes"
        case .SNG: return "Song of Solomon"
        case .ISA: return "Isaiah"
        case .JER: return "Jeremiah"
        case .LAM: return "Lamentations"
        case .EZK: return "Ezekiel"
        case .DAN: return "Daniel"
        case .HOS: return "Hosea"
        case .JOL: return "Joel"
        case .AMO: return "Amos"
        case .OBA: return "Obadiah"
        case .JON: return "Jonah"
        case .MIC: return "Micah"
        case .NAM: return "Nahum"
        case .HAB: return "Habakkuk"
        case .ZEP: return "Zephaniah"
        case .HAG: return "Haggai"
        case .ZEC: return "Zechariah"
        case .MAL: return "Malachi"
        case .MAT: return "Matthew"
        case .MRK: return "Mark"
        case .LUK: return "Luke"
        case .JHN: return "John"
        case .ACT: return "Acts"
        case .ROM: return "Romans"
        case .CO1: return "1 Corinthians"
        case .CO2: return "2 Corinthians"
        case .GAL: return "Galatians"
        case .EPH: return "Ephesians"
        case .PHP: return "Philippians"
        case .COL: return "Colossians"
        case .TH1: return "1 Thessalonians"
        case .TH2: return "2 Thessalonians"
        case .TI1: return "1 Timothy"
        case .TI2: return "2 Timothy"
        case .TIT: return "Titus"
        case .PHM: return "Philemon"
        case .HEB: return "Hebrews"
        case .JAS: return "James"
        case .PE1: return "1 Peter"
        case .PE2: return "2 Peter"
        case .JN1: return "1 John"
        case .JN2: return "2 John"
        case .JN3: return "3 John"
        case .JUD: return "Jude"
        case .REV: return "Revelation"
        }
    }

    /// Books that should receive looser line-height and verse spacing in the reader.
    /// Per design: visual treatment driven by book, not by per-verse data.
    var isPoetic: Bool {
        switch self {
        case .JOB, .PSA, .PRO, .ECC, .SNG, .LAM:
            return true
        default:
            return false
        }
    }

    /// True when verse 1 may begin with a Psalm-style superscription that the
    /// loader should detect and split. WEB lumps them into verse 1, e.g.
    /// "A Psalm by David. Yahweh is my shepherd…"
    var hasSuperscriptions: Bool {
        self == .PSA
    }

    static let oldTestament: [Book] = Book.allCases.filter { $0.testament == .old }
    static let newTestament: [Book] = Book.allCases.filter { $0.testament == .new }

    /// Resolve a book by its English display name (the key used by most
    /// flat-format Bible JSON sources). Case-insensitive.
    static func from(displayName: String) -> Book? {
        let target = displayName.lowercased()
        return Book.allCases.first { $0.displayName.lowercased() == target }
    }
}
