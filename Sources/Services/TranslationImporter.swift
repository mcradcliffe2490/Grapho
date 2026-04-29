import Foundation

enum TranslationImporterError: LocalizedError {
    case copyFailed(underlying: Error)
    case invalidContent(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .copyFailed(let underlying):
            return "Could not copy the translation file: \(underlying.localizedDescription)"
        case .invalidContent(let underlying):
            return "The selected file isn't a valid Bible JSON: \(underlying.localizedDescription)"
        }
    }
}

/// Result of a successful import — gives the caller everything it needs to
/// switch the active translation without re-deriving from the URL.
struct ImportedTranslation {
    let identifier: String
    let displayName: String
    let storedURL: URL
}

/// Handles `.fileImporter`-driven translation imports: validates the JSON
/// against the loader, then copies the file into the app's Documents
/// directory under a stable, slug-derived filename.
struct TranslationImporter {

    private let fileManager: FileManager
    private let loader: BibleLoader

    init(fileManager: FileManager = .default, loader: BibleLoader = BibleLoader()) {
        self.fileManager = fileManager
        self.loader = loader
    }

    /// Validate, normalize, and copy. The source URL typically comes from
    /// `.fileImporter`, which supplies a security-scoped URL; the caller must
    /// invoke `startAccessingSecurityScopedResource` before passing it in.
    func importTranslation(from sourceURL: URL) throws -> ImportedTranslation {
        let displayName = sourceURL
            .deletingPathExtension()
            .lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
        let identifier = Self.slug(from: displayName)
        let destURL = try documentsURL().appendingPathComponent("\(identifier).json")

        // Copy first (validation reads from the destination so we exercise
        // the exact path the runtime app will use).
        do {
            if fileManager.fileExists(atPath: destURL.path) {
                try fileManager.removeItem(at: destURL)
            }
            try fileManager.copyItem(at: sourceURL, to: destURL)
        } catch {
            throw TranslationImporterError.copyFailed(underlying: error)
        }

        // Validate by attempting a full parse. If parsing fails, undo the copy.
        do {
            _ = try loader.loadImported(at: destURL, identifier: identifier, displayName: displayName)
        } catch {
            try? fileManager.removeItem(at: destURL)
            throw TranslationImporterError.invalidContent(underlying: error)
        }

        return ImportedTranslation(identifier: identifier, displayName: displayName, storedURL: destURL)
    }

    /// Removes a previously imported translation's file. Annotations remain
    /// in SwiftData (scoped by translation slug) so re-importing reattaches.
    func removeImported(identifier: String) throws {
        let url = try documentsURL().appendingPathComponent("\(identifier).json")
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    /// URL of the file backing a given translation slug, if present.
    func storedURL(for identifier: String) throws -> URL? {
        let url = try documentsURL().appendingPathComponent("\(identifier).json")
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - Helpers

    private func documentsURL() throws -> URL {
        try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    }

    /// Lower-cased, hyphen-delimited, alphanumeric slug. "NEW INTERNATIONAL
    /// VERSION" → "new-international-version".
    static func slug(from displayName: String) -> String {
        let lowered = displayName.lowercased()
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789")
        var out = ""
        var lastWasHyphen = false
        for ch in lowered {
            if allowed.contains(ch) {
                out.append(ch)
                lastWasHyphen = false
            } else if !lastWasHyphen, !out.isEmpty {
                out.append("-")
                lastWasHyphen = true
            }
        }
        if out.hasSuffix("-") { out.removeLast() }
        return out.isEmpty ? "translation" : out
    }
}
