import SwiftUI
import SwiftData

/// User-facing preferences. Three groups:
/// 1. Reading surface — palette + header mode
/// 2. Drawing — pencil-only-draw toggle for Apple Pencil users
/// 3. Translations — list of imported translations with switch + delete
struct SettingsView: View {
    @Environment(BibleStore.self) private var bibleStore

    @AppStorage(PreferenceKey.backgroundPalette) private var paletteRaw: String = BackgroundPalette.default.rawValue
    @AppStorage(PreferenceKey.headerMode) private var headerModeRaw: String = HeaderMode.custom.rawValue
    @AppStorage(PreferenceKey.pencilOnlyDraw) private var pencilOnly: Bool = false
    @AppStorage(PreferenceKey.readingMode) private var readingModeRaw: String = ReadingMode.default.rawValue

    @State private var imported: [ImportedTranslation] = []
    @State private var deleteCandidate: ImportedTranslation?

    private var palette: BackgroundPalette { .current(rawValue: paletteRaw) }
    private var headerMode: HeaderMode { .current(rawValue: headerModeRaw) }

    var body: some View {
        Form {
            translationSection
            readingModeSection
            readingSection
            drawingSection
            aboutSection
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task { reloadImported() }
        .alert("Remove translation?", isPresented: Binding(
            get: { deleteCandidate != nil },
            set: { if !$0 { deleteCandidate = nil } }
        ), presenting: deleteCandidate) { translation in
            Button("Cancel", role: .cancel) { deleteCandidate = nil }
            Button("Remove", role: .destructive) {
                deleteImported(translation)
            }
        } message: { translation in
            Text("\"\(translation.displayName)\" will be deleted from this device. Annotations are preserved and reattach if you re-import the same file.")
        }
    }

    // MARK: - Translation manager

    private var translationSection: some View {
        Section("Translation") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Active")
                        .font(.callout)
                    Text(bibleStore.translation?.displayName ?? "—")
                        .font(.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                }
                Spacer()
                if let active = bibleStore.translation, active.identifier != BibleLoader.bundledIdentifier {
                    Button("Use Bundled") {
                        Task { await bibleStore.activateBundled() }
                    }
                    .font(.footnote)
                }
            }

            ForEach(imported, id: \.identifier) { translation in
                HStack {
                    VStack(alignment: .leading) {
                        Text(translation.displayName)
                        Text(translation.identifier)
                            .font(.caption2)
                            .foregroundStyle(AppColor.textFaint)
                    }
                    Spacer()
                    if bibleStore.translation?.identifier == translation.identifier {
                        Image(systemName: "checkmark")
                            .foregroundStyle(AppColor.layerExegetical)
                    } else {
                        Button("Activate") {
                            Task { await bibleStore.activate(imported: translation) }
                        }
                        .font(.footnote)
                    }
                    Button {
                        deleteCandidate = translation
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            if imported.isEmpty {
                Text("No imported translations. Tap Import on Home to add one.")
                    .font(.footnote)
                    .foregroundStyle(AppColor.textFaint)
            }
        }
    }

    // MARK: - Reading mode

    /// "How you sit with the text" (design turn 4a): Read & Study or Paper.
    /// Notes from each stay put — switch back and they're waiting.
    private var readingModeSection: some View {
        Section {
            ForEach(ReadingMode.allCases) { mode in
                Button {
                    readingModeRaw = mode.rawValue
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        modeIcon(mode)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mode.displayName)
                                .font(.callout)
                                .foregroundStyle(AppColor.textPrimary)
                            Text(mode.blurb)
                                .font(.caption)
                                .foregroundStyle(AppColor.textMuted)
                        }
                        Spacer()
                        if readingModeRaw == mode.rawValue {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(mode == .paper ? Color(hex: "#8A7A5A") : AppColor.layerExegetical)
                                .padding(.top, 2)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Reading Mode")
        } footer: {
            Text("This changes the whole reading experience. Notes from each stay put — switch back and they're waiting.")
        }
    }

    @ViewBuilder
    private func modeIcon(_ mode: ReadingMode) -> some View {
        switch mode {
        case .readStudy:
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColor.layerExegetical.opacity(0.08))
                .frame(width: 30, height: 30)
                .overlay {
                    let widths: [CGFloat] = [13, 13, 9]
                    VStack(alignment: .leading, spacing: 2.5) {
                        ForEach(widths.indices, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(AppColor.layerExegetical)
                                .frame(width: widths[i], height: 1.6)
                        }
                    }
                }
        case .paper:
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "#8A7A5A").opacity(0.1))
                .frame(width: 30, height: 30)
                .overlay {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "#FCFBF7"))
                        .frame(width: 16, height: 20)
                        .overlay {
                            VStack(spacing: 3) {
                                Rectangle().fill(Color(hex: "#D8CDB6")).frame(width: 10, height: 1)
                                Rectangle().fill(Color(hex: "#D8CDB6")).frame(width: 7, height: 1)
                            }
                        }
                        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Color(hex: "#C9BFA6"), lineWidth: 1))
                }
        }
    }

    // MARK: - Reading

    private var readingSection: some View {
        Section("Reading") {
            // Palette picker — visual swatches in a grid.
            VStack(alignment: .leading, spacing: 12) {
                Text("Background")
                    .font(.callout)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 84, maximum: 120), spacing: 12)], spacing: 12) {
                    ForEach(BackgroundPalette.allCases) { option in
                        paletteSwatch(option)
                    }
                }
            }
            .padding(.vertical, 4)

            Picker("Section headers", selection: $headerModeRaw) {
                ForEach(HeaderMode.allCases) { mode in
                    Text(mode.displayName).tag(mode.rawValue)
                }
            }
        }
    }

    private func paletteSwatch(_ option: BackgroundPalette) -> some View {
        Button {
            paletteRaw = option.rawValue
        } label: {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(option.color)
                    .frame(height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                option == palette ? AppColor.textPrimary : AppColor.border,
                                lineWidth: option == palette ? 2 : 0.5
                            )
                    )
                Text(option.displayName)
                    .font(.caption2)
                    .foregroundStyle(option == palette ? AppColor.textPrimary : AppColor.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Drawing

    private var drawingSection: some View {
        Section("Drawing") {
            Toggle("Apple Pencil only", isOn: $pencilOnly)
            Text("When on, finger touches scroll the page instead of drawing on the scratchpad. Recommended if you use Apple Pencil.")
                .font(.caption)
                .foregroundStyle(AppColor.textFaint)
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: "0.1.0")
            LabeledContent("Bundled translation", value: "World English Bible (public domain)")
        }
    }

    // MARK: - Helpers

    private func reloadImported() {
        imported = TranslationImporter().listImported()
            .filter { $0.identifier != BibleLoader.bundledIdentifier }
    }

    private func deleteImported(_ translation: ImportedTranslation) {
        let importer = TranslationImporter()
        try? importer.removeImported(identifier: translation.identifier)
        // If we just deleted the active translation, fall back to bundled.
        if bibleStore.translation?.identifier == translation.identifier {
            Task { await bibleStore.activateBundled() }
        }
        reloadImported()
        deleteCandidate = nil
    }
}
