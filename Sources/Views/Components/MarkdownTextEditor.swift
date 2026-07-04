import SwiftUI
import UIKit

/// Markdown note editor. The note body stays plain markdown text in
/// SwiftData; this editor styles it live as you type — `**bold**` renders
/// bold with the asterisks faded, `## ` turns the line into a heading — so
/// anyone who knows markdown can just write it, and the format bar wraps or
/// prefixes the selection for everyone else.
///
/// `TextEditor` can't do any of this on iOS 17 (no attributes, no selection
/// access), hence the `UITextView` bridge. Styling only ever touches
/// *attributes*, never the string, so the cursor and undo stack stay intact.
struct MarkdownTextEditor: UIViewRepresentable {
    @Binding var text: String
    /// Handle for the format bar's selection-aware actions.
    var controller: MarkdownEditController?

    func makeUIView(context: Context) -> UITextView {
        let textView = KeyCommandTextView()
        textView.editController = controller
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        // Self-sizing: the parent ScrollView scrolls, not the text view.
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.text = text
        MarkdownStyler.restyle(textView)
        controller?.textView = textView
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        controller?.textView = textView
        (textView as? KeyCommandTextView)?.editController = controller
        // External change only (e.g. selection swap) — never echo back the
        // text the user is mid-typing.
        if textView.text != text {
            textView.text = text
            MarkdownStyler.restyle(textView)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0, width.isFinite else { return nil }
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: max(size.height, 44))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkdownTextEditor

        init(parent: MarkdownTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            MarkdownStyler.restyle(textView)
        }
    }
}

/// A `UITextView` that answers ⌘B / ⌘I from a hardware keyboard — the same
/// toggle-wrap the format bar's B/I buttons trigger. Physical-keyboard iPad
/// use is common enough for a notes app that this shouldn't wait on the
/// on-screen bar.
private final class KeyCommandTextView: UITextView {
    weak var editController: MarkdownEditController?

    override var keyCommands: [UIKeyCommand]? {
        [
            UIKeyCommand(input: "b", modifierFlags: .command, action: #selector(handleBold)),
            UIKeyCommand(input: "i", modifierFlags: .command, action: #selector(handleItalic))
        ]
    }

    @objc private func handleBold() {
        editController?.toggleWrap("**")
    }

    @objc private func handleItalic() {
        editController?.toggleWrap("*")
    }
}

// MARK: - Format bar actions

/// Selection-aware markdown edits, driven by the format bar. Mutations go
/// through `UITextView.replace` so they land on the undo stack like typing.
@MainActor
final class MarkdownEditController {
    weak var textView: UITextView?

    /// Wrap the selection in an inline mark (`**`, `*`, `` ` ``) — or unwrap
    /// it if it's already wrapped. Empty selection inserts a pair and parks
    /// the cursor inside.
    func toggleWrap(_ mark: String) {
        guard let textView else { return }
        let selection = textView.selectedRange
        let markLength = (mark as NSString).length

        if selection.length == 0 {
            replace(selection, with: mark + mark)
            textView.selectedRange = NSRange(location: selection.location + markLength, length: 0)
            return
        }

        let selected = (textView.text as NSString).substring(with: selection)
        if selected.hasPrefix(mark), selected.hasSuffix(mark),
           (selected as NSString).length >= 2 * markLength {
            let inner = String(selected.dropFirst(mark.count).dropLast(mark.count))
            replace(selection, with: inner)
            textView.selectedRange = NSRange(location: selection.location, length: (inner as NSString).length)
        } else {
            replace(selection, with: mark + selected + mark)
            textView.selectedRange = NSRange(location: selection.location + markLength, length: selection.length)
        }
    }

    /// Toggle a line prefix (`## `, `> `, `- `) on every line the selection
    /// touches. `alternatives` are swapped out rather than stacked (tapping
    /// H2 on an H1 line changes the level instead of producing `## # `).
    func toggleLinePrefix(_ prefix: String, alternatives: [String] = []) {
        guard let textView else { return }
        let ns = textView.text as NSString
        let lineRange = ns.lineRange(for: textView.selectedRange)
        let block = ns.substring(with: lineRange)
        let hadTrailingNewline = block.hasSuffix("\n")

        var lines = block.components(separatedBy: "\n")
        if hadTrailingNewline { lines.removeLast() }
        let allPrefixed = lines.allSatisfy { $0.hasPrefix(prefix) || $0.isEmpty }

        let rewritten = lines.map { line -> String in
            var line = line
            if line.isEmpty { return line }
            for old in [prefix] + alternatives where line.hasPrefix(old) {
                line = String(line.dropFirst(old.count))
            }
            return allPrefixed ? line : prefix + line
        }
        let replacement = rewritten.joined(separator: "\n") + (hadTrailingNewline ? "\n" : "")

        replace(lineRange, with: replacement)
        // Select the rewritten block so a second tap toggles cleanly.
        textView.selectedRange = NSRange(location: lineRange.location, length: (replacement as NSString).length - (hadTrailingNewline ? 1 : 0))
    }

    private func replace(_ range: NSRange, with string: String) {
        guard let textView,
              let start = textView.position(from: textView.beginningOfDocument, offset: range.location),
              let end = textView.position(from: start, offset: range.length),
              let textRange = textView.textRange(from: start, to: end)
        else { return }
        textView.replace(textRange, withText: string)
    }
}

/// The quiet formatting rail from design 10a: B I " • H2. Sits in an editor's
/// top rail; every action routes through the shared controller.
struct MarkdownFormatBar: View {
    let controller: MarkdownEditController
    var color: Color = Color(hex: "#BEB7AB")

    var body: some View {
        HStack(spacing: 16) {
            barButton("Bold") {
                Text("B").font(Font.custom("Inter", size: 13).weight(.bold))
            } action: {
                controller.toggleWrap("**")
            }
            barButton("Italic") {
                Text("I").font(Font.custom("CrimsonText-Italic", size: 15))
            } action: {
                controller.toggleWrap("*")
            }
            barButton("Quote") {
                Text("\u{201C}").font(Font.custom("CrimsonText-Regular", size: 18))
            } action: {
                controller.toggleLinePrefix("> ")
            }
            barButton("Bullet list") {
                Text("•").font(Font.custom("Inter", size: 15))
            } action: {
                controller.toggleLinePrefix("- ", alternatives: ["* ", "+ "])
            }
            barButton("Heading") {
                Text("H2").font(Font.custom("Inter", size: 11).weight(.bold))
            } action: {
                controller.toggleLinePrefix("## ", alternatives: ["# ", "### "])
            }
        }
        .foregroundStyle(color)
    }

    private func barButton(
        _ label: String,
        @ViewBuilder content: () -> some View,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            content()
                .frame(minWidth: 18, minHeight: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Live styling

/// Applies markdown presentation to a `UITextView`'s text storage —
/// attributes only, never the characters, so typing is never disturbed.
/// Covered syntax: `#`/`##`/`###` headings, `> ` quotes, list markers,
/// `**bold**`, `*italic*`/`_italic_`, `` `code` ``. Syntax marks fade to the
/// margin color instead of hiding, iA-Writer-style, so what you see is
/// always exactly what's stored.
enum MarkdownStyler {

    static func restyle(_ textView: UITextView) {
        let storage = textView.textStorage
        let full = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.setAttributes(baseAttributes, range: full)
        styleBlocks(storage)
        styleInline(storage)
        storage.endEditing()
        textView.typingAttributes = baseAttributes
    }

    // MARK: Palette & fonts

    private static let bodyColor = UIColor(Color(hex: "#2B2723"))
    private static let markColor = UIColor(Color(hex: "#C4BFB8"))
    private static let quoteColor = UIColor(Color(hex: "#6B655D"))

    private static func crimson(_ name: String, _ size: CGFloat) -> UIFont {
        UIFont(name: name, size: size) ?? .systemFont(ofSize: size)
    }

    static var baseAttributes: [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 8
        return [
            .font: crimson("CrimsonText-Regular", 18),
            .foregroundColor: bodyColor,
            .paragraphStyle: paragraph
        ]
    }

    // MARK: Rules

    private static let headingRegex = try! NSRegularExpression(
        pattern: #"^(#{1,3})[ \t]+.*$"#, options: [.anchorsMatchLines]
    )
    private static let quoteRegex = try! NSRegularExpression(
        pattern: #"^(>[ \t]?).*$"#, options: [.anchorsMatchLines]
    )
    private static let listRegex = try! NSRegularExpression(
        pattern: #"^[ \t]*([-*+]|\d+\.)[ \t]"#, options: [.anchorsMatchLines]
    )
    private static let boldRegex = try! NSRegularExpression(
        pattern: #"(\*\*)([^\*\n]+)(\*\*)"#
    )
    private static let italicStarRegex = try! NSRegularExpression(
        pattern: #"(?<![\*\w])(\*)([^\*\n]+)(\*)(?!\*)"#
    )
    private static let italicUnderscoreRegex = try! NSRegularExpression(
        pattern: #"(?<!\w)(_)([^_\n]+)(_)(?!\w)"#
    )
    private static let codeRegex = try! NSRegularExpression(
        pattern: #"(`)([^`\n]+)(`)"#
    )

    private static func styleBlocks(_ storage: NSTextStorage) {
        let full = NSRange(location: 0, length: storage.length)

        headingRegex.enumerateMatches(in: storage.string, range: full) { match, _, _ in
            guard let match else { return }
            let level = match.range(at: 1).length
            let size: CGFloat = [28, 23, 20][min(level, 3) - 1]
            storage.addAttribute(.font, value: crimson("CrimsonText-Bold", size), range: match.range)
            // Fade the `##` marks (and the space after them).
            let marks = NSRange(location: match.range(at: 1).location, length: match.range(at: 1).length + 1)
            storage.addAttribute(.foregroundColor, value: markColor, range: marks)
        }

        quoteRegex.enumerateMatches(in: storage.string, range: full) { match, _, _ in
            guard let match else { return }
            storage.addAttribute(.font, value: crimson("CrimsonText-Italic", 18), range: match.range)
            storage.addAttribute(.foregroundColor, value: quoteColor, range: match.range)
            storage.addAttribute(.foregroundColor, value: markColor, range: match.range(at: 1))
        }

        listRegex.enumerateMatches(in: storage.string, range: full) { match, _, _ in
            guard let match else { return }
            storage.addAttribute(.foregroundColor, value: markColor, range: match.range(at: 1))
        }
    }

    private static func styleInline(_ storage: NSTextStorage) {
        let full = NSRange(location: 0, length: storage.length)

        // Bold / italic derive from the font already on the run, so inline
        // marks inside a heading keep the heading's size.
        applySpan(boldRegex, in: storage, range: full) { current in
            crimson("CrimsonText-Bold", current.pointSize)
        }
        applySpan(italicStarRegex, in: storage, range: full) { current in
            crimson("CrimsonText-Italic", current.pointSize)
        }
        applySpan(italicUnderscoreRegex, in: storage, range: full) { current in
            crimson("CrimsonText-Italic", current.pointSize)
        }

        codeRegex.enumerateMatches(in: storage.string, range: full) { match, _, _ in
            guard let match else { return }
            storage.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: 15, weight: .regular), range: match.range(at: 2))
            storage.addAttribute(.backgroundColor, value: UIColor(Color(hex: "#F2F0EC")), range: match.range(at: 2))
            storage.addAttribute(.foregroundColor, value: markColor, range: match.range(at: 1))
            storage.addAttribute(.foregroundColor, value: markColor, range: match.range(at: 3))
        }
    }

    /// Style groups (1)(2)(3) = opening mark, content, closing mark. The
    /// content's font is transformed per-run; the marks fade.
    private static func applySpan(
        _ regex: NSRegularExpression,
        in storage: NSTextStorage,
        range: NSRange,
        transform: @escaping (UIFont) -> UIFont
    ) {
        regex.enumerateMatches(in: storage.string, range: range) { match, _, _ in
            guard let match else { return }
            let content = match.range(at: 2)
            storage.enumerateAttribute(.font, in: content) { value, run, _ in
                let current = value as? UIFont ?? crimson("CrimsonText-Regular", 18)
                storage.addAttribute(.font, value: transform(current), range: run)
            }
            storage.addAttribute(.foregroundColor, value: markColor, range: match.range(at: 1))
            storage.addAttribute(.foregroundColor, value: markColor, range: match.range(at: 3))
        }
    }
}
