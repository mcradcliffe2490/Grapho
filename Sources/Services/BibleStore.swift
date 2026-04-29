import Foundation
import Observation

/// Holds the active `BibleTranslation` in memory and exposes it to the view
/// hierarchy via `@Environment`. Loading happens asynchronously so the launch
/// path doesn't block on the ~4 MB WEB JSON parse.
///
/// The `loadingState` distinguishes the initial load from runtime load
/// failures. Views render a loader during `.idle` / `.loading`, the active
/// translation when `.loaded`, and a recovery affordance on `.failed`.
@Observable
@MainActor
final class BibleStore {

    enum LoadingState: Equatable {
        case idle
        case loading
        case loaded
        case failed(message: String)
    }

    private(set) var translation: BibleTranslation?
    private(set) var loadingState: LoadingState = .idle

    private let loader: BibleLoader
    private let importer: TranslationImporter

    init(loader: BibleLoader = BibleLoader(), importer: TranslationImporter = TranslationImporter()) {
        self.loader = loader
        self.importer = importer
    }

    /// Boot-time load. Reads the active translation slug from preferences and
    /// attempts to load it; falls back to the bundled WEB on any error.
    func loadInitialTranslation() async {
        guard loadingState != .loaded, loadingState != .loading else { return }
        loadingState = .loading

        let activeSlug = UserDefaults.standard.string(forKey: PreferenceKey.activeTranslation)
            ?? BibleLoader.bundledIdentifier

        let result = await loadTranslation(slug: activeSlug)
        switch result {
        case .success(let parsed):
            translation = parsed
            loadingState = .loaded
            UserDefaults.standard.set(parsed.identifier, forKey: PreferenceKey.activeTranslation)
        case .failure:
            // If the configured translation can't load, fall back to bundled
            // WEB so the user is never stuck on an empty home screen.
            let fallback = await loadTranslation(slug: BibleLoader.bundledIdentifier)
            switch fallback {
            case .success(let parsed):
                translation = parsed
                loadingState = .loaded
                UserDefaults.standard.set(parsed.identifier, forKey: PreferenceKey.activeTranslation)
            case .failure(let error):
                loadingState = .failed(message: error.localizedDescription)
            }
        }
    }

    /// Switch to an imported translation. Caller has already validated &
    /// stored the file via `TranslationImporter`.
    func activate(imported: ImportedTranslation) async {
        loadingState = .loading
        do {
            let parsed = try loader.loadImported(
                at: imported.storedURL,
                identifier: imported.identifier,
                displayName: imported.displayName
            )
            translation = parsed
            loadingState = .loaded
            UserDefaults.standard.set(parsed.identifier, forKey: PreferenceKey.activeTranslation)
        } catch {
            loadingState = .failed(message: error.localizedDescription)
        }
    }

    /// Switch back to the bundled WEB.
    func activateBundled() async {
        let result = await loadTranslation(slug: BibleLoader.bundledIdentifier)
        switch result {
        case .success(let parsed):
            translation = parsed
            loadingState = .loaded
            UserDefaults.standard.set(parsed.identifier, forKey: PreferenceKey.activeTranslation)
        case .failure(let error):
            loadingState = .failed(message: error.localizedDescription)
        }
    }

    // MARK: - Private

    private func loadTranslation(slug: String) async -> Result<BibleTranslation, Error> {
        if slug == BibleLoader.bundledIdentifier {
            return await Task.detached(priority: .userInitiated) { [loader] in
                Result { try loader.loadBundled() }
            }.value
        } else {
            // Imported translation: look up its storage URL, then parse.
            do {
                guard let url = try importer.storedURL(for: slug) else {
                    return .failure(BibleLoaderError.fileNotFound(URL(fileURLWithPath: "\(slug).json")))
                }
                let displayName = slug
                    .replacingOccurrences(of: "-", with: " ")
                    .capitalized
                return await Task.detached(priority: .userInitiated) { [loader] in
                    Result { try loader.loadImported(at: url, identifier: slug, displayName: displayName) }
                }.value
            } catch {
                return .failure(error)
            }
        }
    }
}
