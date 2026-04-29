import SwiftUI

/// Single verse row. Inline verse number rendered with `.baselineOffset` so it
/// reads as a proper superscript without leaving a separate column hanging.
///
/// Poetic vs prose treatment is driven by `Book.isPoetic` — poetic books get
/// looser inter-verse spacing (each verse on its own block) while prose books
/// flow continuously. We're explicitly *not* doing line indentation in v1
/// (the public-domain JSON sources don't carry that data).
struct VerseView: View {
    let verse: BibleVerse
    let isPoetic: Bool

    var body: some View {
        Group {
            if isPoetic {
                Text(verseAttributed)
                    .font(AppFont.scriptureBody)
                    .lineSpacing(AppSpacing.scriptureLineSpacing)
                    .foregroundStyle(AppColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // Prose: flow inline. The parent uses a single Text with all
                // verses concatenated for proper word-wrap; this branch is
                // here for the rare case a caller wants per-verse rendering.
                Text(verseAttributed)
                    .font(AppFont.scriptureBody)
                    .lineSpacing(AppSpacing.scriptureLineSpacing)
                    .foregroundStyle(AppColor.textPrimary)
            }
        }
    }

    private var verseAttributed: AttributedString {
        var num = AttributedString("\(verse.number) ")
        num.font = AppFont.verseNumber
        num.foregroundColor = AppColor.textFaint
        num.baselineOffset = 4

        var body = AttributedString(verse.text)
        body.font = AppFont.scriptureBody
        body.foregroundColor = AppColor.textPrimary

        return num + body
    }
}
