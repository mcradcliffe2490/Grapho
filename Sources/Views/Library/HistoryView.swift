import SwiftUI
import SwiftData

/// Phase 3 placeholder showing recent chapter visits. Wired against `ChapterVisit`
/// directly via `@Query` so it works as soon as the reader starts logging.
struct HistoryView: View {
    @Query(sort: \ChapterVisit.visitedAt, order: .reverse) private var visits: [ChapterVisit]

    var body: some View {
        Group {
            if visits.isEmpty {
                EmptyLibraryStub(
                    title: "History",
                    message: "Chapters you read will be listed here in reverse order."
                )
            } else {
                List(visits) { visit in
                    if let book = Book(rawValue: visit.book) {
                        NavigationLink(value: ChapterRoute(book: book, chapter: visit.chapter)) {
                            HistoryRow(book: book, chapter: visit.chapter, visitedAt: visit.visitedAt)
                        }
                    }
                }
                .listStyle(.plain)
                .navigationTitle("History")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

private struct HistoryRow: View {
    let book: Book
    let chapter: Int
    let visitedAt: Date

    var body: some View {
        HStack {
            Text("\(book.displayName) \(chapter)")
                .foregroundStyle(AppColor.textPrimary)
            Spacer()
            Text(visitedAt, style: .relative)
                .font(.caption)
                .foregroundStyle(AppColor.textFaint)
        }
    }
}

#Preview {
    NavigationStack { HistoryView() }
        .modelContainer(AppModelContainer.preview.container)
}
