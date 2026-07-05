import SwiftUI

/// The verse tap menu and everything it leads to, hosted in one popover so
/// the anchor never jumps (design turn 8a):
///
///   actions (dark pill: Highlight · Note · Thread…)
///     ├─ highlight → the four color dots (+ clear)
///     └─ thread    → target picker (search + shared-word suggestions)
///                      └─ why → "why these connect for you" one-liner
///
/// The parent owns persistence; this view only reports intent through the
/// callbacks and steps between screens.
struct VerseActionPopover: View {
    let sourceRef: VerseRef
    let translation: BibleTranslation
    let mode: LayerKind
    let currentHighlight: HighlightColor?
    /// Existing section-header text above this verse; empty when none. The
    /// Header step prefills with it so tap-to-edit and create share a flow.
    let existingHeader: String
    let onHighlight: (HighlightColor?) -> Void
    let onNote: () -> Void
    /// Save the header above this verse; empty text removes it.
    let onHeader: (String) -> Void
    /// Create the thread and return it so the why-step can amend it.
    let onCreateThread: (VerseRef) -> VerseThread
    let onSetWhy: (VerseThread, String) -> Void
    let onClose: () -> Void

    private enum Step {
        case actions
        case highlight
        case header
        case thread
    }

    @State private var step: Step = .actions
    @State private var headerDraft = ""

    private var isDark: Bool {
        switch step {
        case .actions, .highlight: return true
        case .header, .thread: return false
        }
    }

    var body: some View {
        Group {
            switch step {
            case .actions: actionsRow
            case .highlight: highlightRow
            case .header: headerEditor
            case .thread:
                ThreadPickerFlow(
                    sourceRef: sourceRef,
                    translation: translation,
                    mode: mode,
                    onCreateThread: onCreateThread,
                    onSetWhy: onSetWhy,
                    onDone: onClose
                )
            }
        }
        .presentationBackground(isDark ? AppColor.inkSurface : Color.white)
        .presentationCompactAdaptation(.popover)
    }

    // MARK: - Step 1: actions

    private var actionsRow: some View {
        HStack(spacing: 0) {
            menuItem("Highlight") { step = .highlight }
            menuDivider
            menuItem("Note", action: onNote)
            menuDivider
            menuItem("Header") {
                headerDraft = existingHeader
                step = .header
            }
            menuDivider
            Button {
                step = .thread
            } label: {
                HStack(spacing: 5) {
                    Circle().fill(mode.accentColor).frame(width: 6, height: 6)
                    Text("Thread…")
                }
                .font(AppFont.uiBody)
                .foregroundStyle(mode.accentColor.lightened)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .padding(5)
    }

    private func menuItem(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(AppFont.uiBody)
                .foregroundStyle(AppColor.inkText)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private var menuDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.15))
            .frame(width: 1)
            .padding(.vertical, 5)
    }

    // MARK: - Step: section header

    private var headerEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HEADER BEFORE VERSE \(sourceRef.verse)")
                .font(AppFont.microCaps)
                .tracking(1.5)
                .foregroundStyle(AppColor.textMuted)
            TextField("Section title", text: $headerDraft)
                .font(AppFont.uiBody)
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 8).fill(AppColor.surface))
                .onSubmit {
                    onHeader(headerDraft)
                }
            HStack {
                if !existingHeader.isEmpty {
                    Button("Remove") {
                        onHeader("")
                    }
                    .font(AppFont.uiBody)
                    .foregroundStyle(.red)
                    .buttonStyle(.plain)
                }
                Spacer()
                Button("Save") {
                    onHeader(headerDraft)
                }
                .font(AppFont.uiBody)
                .foregroundStyle(AppColor.textPrimary)
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(width: 300)
    }

    // MARK: - Step 2: highlight colors

    private var highlightRow: some View {
        HStack(spacing: 12) {
            ForEach(HighlightColor.allCases) { color in
                Button {
                    onHighlight(color)
                } label: {
                    Circle()
                        .fill(color.color)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle().strokeBorder(
                                color == currentHighlight ? .white : .clear,
                                lineWidth: 1.5
                            )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Highlight \(color.rawValue)")
            }
            if currentHighlight != nil {
                Button {
                    onHighlight(nil)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColor.inkText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear highlight")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

}

/// The thread-creation flow — target picker, then the "why these connect"
/// one-liner. Shared by the verse action menu and the note editor's Thread
/// button (design turns 8a/10a).
struct ThreadPickerFlow: View {
    let sourceRef: VerseRef
    let translation: BibleTranslation
    let mode: LayerKind
    let onCreateThread: (VerseRef) -> VerseThread
    let onSetWhy: (VerseThread, String) -> Void
    let onDone: () -> Void

    @State private var created: VerseThread?
    @State private var query = ""
    @State private var suggestions: [ThreadTargetSearch.Candidate] = []
    @State private var why = ""

    var body: some View {
        if let created {
            whyEditor(created)
        } else {
            threadPicker
        }
    }

    private var threadPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("THREAD FROM \(sourceRef.display.uppercased()) TO…")
                .font(AppFont.microCaps)
                .tracking(1.5)
                .foregroundStyle(mode.accentColor)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColor.textFaint)
                TextField("a book, chapter and verse…", text: $query)
                    .font(AppFont.uiBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 8).fill(AppColor.surface))

            if let parsed = search.parseReference(query) {
                candidateRow(parsed)
            } else if !suggestions.isEmpty {
                Text("SUGGESTED · SHARED WORDS")
                    .font(AppFont.microCaps)
                    .tracking(1)
                    .foregroundStyle(AppColor.textFaint)
                    .padding(.top, 2)
                ForEach(suggestions) { candidate in
                    candidateRow(candidate)
                }
            }

            Text("…or thread to anything. It's your connection.")
                .font(AppFont.uiBody)
                .italic()
                .foregroundStyle(AppColor.textFaint)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)
        }
        .padding(14)
        .frame(width: 320)
        .task {
            let search = self.search
            let source = sourceRef
            suggestions = await Task.detached { search.suggestions(for: source) }.value
        }
    }

    private var search: ThreadTargetSearch {
        ThreadTargetSearch(translation: translation)
    }

    private func candidateRow(_ candidate: ThreadTargetSearch.Candidate) -> some View {
        Button {
            created = onCreateThread(candidate.ref)
        } label: {
            HStack(alignment: .firstTextBaseline) {
                Text(candidate.ref.display)
                    .font(AppFont.threadRef)
                    .foregroundStyle(AppColor.textPrimary)
                Spacer(minLength: 12)
                Text(candidate.snippet)
                    .font(AppFont.listSection)
                    .foregroundStyle(AppColor.textMuted)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Why these connect

    private func whyEditor(_ thread: VerseThread) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle().fill(mode.accentColor).frame(width: 6, height: 6)
                Text("THREADED · \(mode.displayName.uppercased())")
                    .font(AppFont.microCaps)
                    .tracking(1.5)
                    .foregroundStyle(mode.accentColor)
            }
            if let to = thread.toRef {
                Text("→ \(to.display)")
                    .font(AppFont.threadRef)
                    .foregroundStyle(AppColor.textPrimary)
            }
            TextField("why these connect for you…", text: $why, axis: .vertical)
                .font(AppFont.uiBody)
                .lineLimit(1...3)
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 8).fill(AppColor.surface))
            Button {
                onSetWhy(thread, why)
                onDone()
            } label: {
                Text("Done")
                    .font(AppFont.uiBody)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 8).fill(mode.accentColor))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(width: 300)
    }
}

extension Color {
    /// A lighter tint for text on dark surfaces — the mock renders "Thread…"
    /// in a pastel of the mode color (#C9A9D9 for thematic).
    var lightened: Color {
        Color(UIColor(self).blended(toward: .white, fraction: 0.45))
    }
}

private extension UIColor {
    func blended(toward other: UIColor, fraction: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(
            red: r1 + (r2 - r1) * fraction,
            green: g1 + (g2 - g1) * fraction,
            blue: b1 + (b2 - b1) * fraction,
            alpha: a1
        )
    }
}
