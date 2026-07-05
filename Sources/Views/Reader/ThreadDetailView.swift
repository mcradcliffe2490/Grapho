import SwiftUI
import SwiftData

/// "Pull thread" — the thread laid out full-length for reading: both verses
/// quoted in full, the mode it was born in, and the whole "why" without any
/// line clamp. Reached by long-pressing a thread anywhere it appears.
///
/// Editing the why happens inline here (it's where you're already reading
/// it); jumping to either end dismisses the sheet and navigates.
struct ThreadDetailView: View {
    let thread: VerseThread
    /// Jump to one end of the thread. The presenter dismisses first.
    let onOpenRef: (VerseRef) -> Void
    let onDelete: () -> Void

    @Environment(BibleStore.self) private var bibleStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var whyDraft = ""
    @State private var isEditingWhy = false
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let from = thread.fromRef {
                        verseCard(from)
                    }
                    threadJoin
                    if let to = thread.toRef {
                        verseCard(to)
                    }
                    whySection
                        .padding(.top, 28)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 36)
            }
        }
        .background(Color(hex: "#FBF9F6").ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .confirmationDialog("Cut this thread?", isPresented: $showDeleteConfirm) {
            Button("Cut thread", role: .destructive) {
                onDelete()
                dismiss()
            }
        } message: {
            Text("Both ends lose the connection. This can't be undone.")
        }
        .onAppear {
            whyDraft = thread.why
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            ThreadLoopIcon()
                .stroke(thread.mode.accentColor, style: ThreadLoopIcon.strokeStyle)
                .frame(width: 15, height: 18)
            Text("THREAD · \(thread.mode.displayName.uppercased())")
                .font(AppFont.microCaps)
                .tracking(1.5)
                .foregroundStyle(thread.mode.accentColor)
            Spacer()
            Text(thread.createdAt.formatted(date: .abbreviated, time: .omitted))
                .font(AppFont.listSection)
                .foregroundStyle(AppColor.textFaint)
            Button {
                showDeleteConfirm = true
            } label: {
                Image(systemName: "scissors")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColor.textFaint)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cut thread")
            .padding(.leading, 8)
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 20)
    }

    // MARK: - Verse ends

    private func verseCard(_ ref: VerseRef) -> some View {
        Button {
            dismiss()
            onOpenRef(ref)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(ref.display.uppercased())
                        .font(AppFont.microCaps)
                        .tracking(1.3)
                        .foregroundStyle(thread.mode.accentColor)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColor.textFaint)
                }
                Text(verseText(ref) ?? "Not available in this translation.")
                    .font(Font.custom("CrimsonText-Italic", size: 19, relativeTo: .title3))
                    .foregroundStyle(Color(hex: "#4A443C"))
                    .lineSpacing(6)
                    .multilineTextAlignment(.leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(.white))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(AppColor.cardBorder, lineWidth: 1)
            )
            .overlay(alignment: .leading) {
                UnevenRoundedRectangle(topLeadingRadius: 12, bottomLeadingRadius: 12)
                    .fill(thread.mode.accentColor)
                    .frame(width: 3)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// The stitch between the two cards — a short run of thread.
    private var threadJoin: some View {
        HStack {
            Spacer()
            VStack(spacing: 2) {
                Rectangle()
                    .fill(thread.mode.accentColor.opacity(0.5))
                    .frame(width: 1.5, height: 10)
                ThreadLoopIcon()
                    .stroke(thread.mode.accentColor, style: ThreadLoopIcon.strokeStyle)
                    .frame(width: 15, height: 18)
                Rectangle()
                    .fill(thread.mode.accentColor.opacity(0.5))
                    .frame(width: 1.5, height: 10)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Why

    private var whySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("WHY THESE CONNECT")
                    .font(AppFont.microCaps)
                    .tracking(1.5)
                    .foregroundStyle(AppColor.textFaint)
                Spacer()
                Button(isEditingWhy ? "Done" : (thread.why.isEmpty ? "Add" : "Edit")) {
                    if isEditingWhy {
                        thread.why = whyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        try? modelContext.save()
                    }
                    isEditingWhy.toggle()
                }
                .font(AppFont.listSection)
                .foregroundStyle(thread.mode.accentColor)
                .buttonStyle(.plain)
            }

            if isEditingWhy {
                TextField("why these connect for you…", text: $whyDraft, axis: .vertical)
                    .font(Font.custom("CrimsonText-Regular", size: 18, relativeTo: .body))
                    .lineLimit(2...10)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.white))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppColor.cardBorder, lineWidth: 1))
            } else if thread.why.isEmpty {
                Text("Nothing yet — pull the thread and say why it holds.")
                    .font(AppFont.threadRef)
                    .italic()
                    .foregroundStyle(AppColor.textFaint)
            } else {
                Text(thread.why)
                    .font(Font.custom("CrimsonText-Regular", size: 18, relativeTo: .body))
                    .foregroundStyle(Color(hex: "#2B2723"))
                    .lineSpacing(8)
            }
        }
    }

    private func verseText(_ ref: VerseRef) -> String? {
        bibleStore.translation?
            .chapter(book: ref.book, number: ref.chapter)?
            .verse(ref.verse)?.text
    }
}
