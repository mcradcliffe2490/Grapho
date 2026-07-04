# Grapho — Plan

Personal iPad Bible-study app. SwiftUI + SwiftData + PencilKit, iPad-only,
local-only. This plan tracks implementation against the Claude Design doc
**"Grapho Reading & Notes.dc.html"**
(claude.ai/design project `f58e97b0-7e88-48a5-a15c-570733c33ba6`), which
evolves the shipped app (its "turn 1" baseline) through ten design turns.

## Decisions (confirmed 2026-07-03)

- **UI approach:** pure SwiftUI + PencilKit. No third-party component library.
- **Platform:** iPad-only for now, but written size-class/geometry-driven (no
  `UIDevice` checks) so iPhone support can be enabled later. The "10b mobile"
  mocks double as the compact-width layout.
- **Thread web:** included — hand-rolled force-directed graph in a SwiftUI
  `Canvas`, no dependency.
- **Paper drawing:** PencilKit (`PKCanvasView` bridge already in the codebase)
  driven by a custom minimal tool pill (pen / ink / highlighter / eraser,
  undo, clear) instead of Apple's floating `PKToolPicker`.
- **Thread icon:** the design doc's loop glyph (diagonal line + tiny loop) is
  replaced with a proper looped-thread mark — drawn as a SwiftUI `Shape`
  (`ThreadLoopIcon`) so it scales and tints anywhere.

## Done (phases 1–7, see git history)

1–4. Buildable iPad reader MVP: WEB Bible bundled + parsed, reader with
     highlights/notes, home & chapter navigation, history.
5–7. Annotation layers (Exegetical / Devotional / Thematic), Scholar split
     mode with PencilKit scratchpad, real Settings, visual redesign per the
     original Figma, Apple-Notes-style right pane, library bubble, notes
     browser, full-screen note editor.

## Phase 8 — Lectio reading page (design turns 2b, 3a)

The reading surface calms down; annotation moves to the margins.

- [x] Hanging verse numbers in the left margin (Inter 10, faint) instead of
      inline superscripts; generous measure/leading per 2b.
- [x] Centered small-caps `BOOK N` chapter label; active mode chip top-right
      (colored dot + small-caps name).
- [x] Section headers become centered Crimson italic with a short hairline.
- [x] Highlights become a "whisper": thin wash under the text (bottom-third
      gradient) rather than a filled rounded box.
- [x] Margin dots on the right edge: one dot per note, colored by the mode it
      was made in (all modes visible while reading, not just the active one).
      Tap → floating note card popover (mode chip + body).
- [x] Verse tap → dark action menu `Highlight · Note · Thread…` (design 8a)
      replacing the inline color-dot row; Highlight expands to the 4-dot
      picker, Note opens the editor, Thread starts Phase 9's flow.

## Phase 9 — Threads (design turns 8, 9)

A thread is a first-class verse→verse connection carrying the mode it was
born in and an optional "why".

- [x] `VerseThread` SwiftData model: from/to (book, chapter, verse),
      `modeRaw`, `why`, `createdAt`, translation-agnostic. Not owned by
      `AnnotationLayer` (threads span chapters); mode stored directly.
- [x] `AnnotationStore` methods: `addThread`, `threads(from:)`,
      `threads(into:)`, `threads(inBook:)`, `deleteThread`.
- [x] Thread picker popover (8a): "THREAD FROM X TO…", reference search
      (parse "John 12:32" style input), suggestions from shared significant
      words (Bible text is in RAM — simple rare-word overlap, no NLP).
- [x] Gutter loop mark (9a): threaded verses show `ThreadLoopIcon` in the
      right margin next to note dots, tinted by thread mode. Tap → popover
      "THREADED TO · n" listing links (dot, target ref, why) — both
      directions, backlinks included (8b: the other side sees it for free).
- [x] Thread web (8c): "Your threads in {Book}" — force-directed graph,
      nodes = verses (sized by degree), edges tinted by mode, legend,
      loose-end invitation. Reached from the library menu.
- [x] Note editor shows `THREADS · n` chips for its anchor verse and
      `LINKED MENTIONS` (9b): notes anchored at verses that thread into this
      note's verse.

## Phase 10 — Study pane (design turns 6b, 7a)

- [x] Scholar split becomes a **reflow split**: draggable divider (text
      reflows, nothing covered), collapses to a thin edge for pure reading.
- [x] Right pane: `STUDY` label, tri-color segmented mode tabs (dot +
      small-caps name, active tab tinted), `NOTES | WRITING` pill.
- [x] Mode switching is horizontal (7a): the three mode "rooms" live on a
      horizontal pager; room slides sideways while the pane tint eases to the
      mode color. Bottom color-dot pager (active dot stretches to a pill) +
      edge chevrons.

## Phase 11 — Paper mode (design turns 3b, 4a, 4c, 5a)

A second app-wide reading practice: freeform, no verse-tied anything.

- [x] `readingMode` preference (`readStudy` / `paper`) + Settings "READING
      MODE" section (4a: two rows with mini-preview icons, checkmark).
- [x] First-run "How will you sit with the text?" chooser (4c), shown once;
      changeable in Settings after.
- [x] Paper chapter view (3b/5a): ruled lines matched to the text line
      height, red margin rule, chapter text printed on the lines
      (superscription italic, title, verses), dashed bottom-margin divider
      with a handwriting hint, `PAPER` label top-right.
- [x] Full-page PencilKit canvas over everything (finger scrolls, pencil
      draws — passthrough machinery already exists); per-chapter
      `PaperPage` @Model persisting `PKDrawing` data.
- [x] Custom tool pill: pen (graphite) / ink (blue) / highlighter / eraser +
      undo + clear, floating bottom-center.

## Phase 12 — Notes browser & editor (design turn 10a)

- [x] Left list (~300pt): `Notes` header + count + `+`, search field,
      books collapse (caret, Crimson bold name, count right-aligned), open
      book groups notes by chapter (small-caps chapter label), note rows:
      mode accent bar + dot, ref, Crimson title, one-line snippet. Canonical
      order throughout.
- [x] Right editor: quiet top rail (anchor dot + `REF · MODE`), title,
      "Edited …" timestamp, anchored verse as a mode-colored blockquote,
      body, `THREADS · n` chip row at the bottom (from Phase 9).
- [x] Formatting rail (B I " • H2) + live markdown: `MarkdownTextEditor`
      (`UITextView` bridge) styles markdown as you type, iA-Writer-style —
      headings, bold/italic, quotes, lists, inline code, syntax marks faded
      but visible. Notes stay plain markdown text in SwiftData. Rail actions
      are selection-aware (wrap/unwrap, line-prefix toggles). Used by all
      three editors: browser column, full-screen, Scholar pane. Previews
      strip syntax via `String.strippingMarkdown` (unit-tested).
- [x] Compact-width variant = the 10b "two rooms" flow (list and editor as
      separate screens), keyed off horizontal size class — this is the
      future iPhone layout for free.

## Verification

- Unit tests: `ChapterNavigator`, `SuperscriptionSplitter`, and the new
  `ThreadTargetSearch` (reference parsing + shared-word suggestions).
- `UITests/ScreenshotTourTests.swift` drives the real app through chooser →
  reader → thread creation → Scholar split → Paper → notes browser and
  attaches a screenshot at each stop:
  `xcodebuild test -scheme Grapho -only-testing:GraphoUITests -resultBundlePath tour.xcresult`
  then `xcrun xcresulttool export attachments --path tour.xcresult --output-path shots/`.
- Fixed in passing: `UIAppFonts` pointed at `Fonts/…` paths but the build
  flattens fonts into the bundle root, so Crimson/Inter had silently never
  registered — the whole app was rendering in San Francisco. Bare filenames
  in `project.yml` fixed it.

## UAT round (2026-07-03)

- [x] Previous-chapter bar at the top of the page, mirroring the footer.
- [x] Anchor picker scrolls once to the current anchor, centered (no snap-back).
- [x] Library bubble icon → hamburger (matches the mocks' drawer affordance).
- [x] Following a thread scrolls to and pulses the exact verse (`ChapterRoute.focusVerse`).
- [x] A thread's "why" surfaces as a shared note-card in the study pane's
      Notes list at *both* ends (stored once on the thread so the ends never
      drift; tap jumps to the other end, long-press edits the why or deletes).
      Chosen over materializing a second `VerseNote` per end — same UX, no
      duplicate rows to keep in sync.
- [x] Bug pass (multi-angle review): focus re-trigger on layer switch, lost
      section-header creation (restored as a Header action on the verse menu),
      stale margins after pop-back, popovers surviving layer switches,
      per-row sort/filter waste, `anchorRef`/preview duplication.

## Riff round (2026-07-04)

- [x] **Pull thread** — long-press a thread (study pane list or gutter
      popover) → a sheet with both verses quoted in full, the mode, the
      unclamped "why" (editable inline), tap either end to jump, scissors to
      cut. Menus now read Pull thread / Edit why… / Cut thread.
- [x] Markdown note editing (see Phase 12 formatting-rail item).

## Deferred / explicitly out

- iPhone target enablement (write for it, don't ship it).
- Rich text storage — notes stay plain text (markdown-friendly) for now.
- 8c graph zoom/pan interactions beyond basics.
- Caveat handwriting font — bundled only if Paper's hint wants it after a
  look at Crimson italic first.
