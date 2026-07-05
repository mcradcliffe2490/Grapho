import SwiftUI

/// First-run "choose your practice" (design turn 4c): Grapho asks once how
/// you'll sit with the text this season. Changeable later in Settings —
/// notes from each practice stay put.
struct PracticeChooserView: View {
    @AppStorage(PreferenceKey.readingMode) private var readingModeRaw: String = ReadingMode.default.rawValue
    @AppStorage(PreferenceKey.hasChosenPractice) private var hasChosenPractice: Bool = false

    @State private var selection: ReadingMode = .readStudy

    var body: some View {
        VStack(spacing: 0) {
            Text("GRAPHO")
                .font(AppFont.wordmark)
                .tracking(3)
                .foregroundStyle(AppColor.textFaint)
                .padding(.top, 60)

            VStack(spacing: 14) {
                Text("How will you sit\nwith the text?")
                    .font(Font.custom("CrimsonText-Regular", size: 32, relativeTo: .largeTitle))
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Grapho works two ways. Choose the one for this season — you can change it anytime in Settings.")
                    .font(AppFont.uiBody)
                    .foregroundStyle(AppColor.textMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
            .padding(.top, 52)

            VStack(spacing: 14) {
                practiceCard(.readStudy, accent: AppColor.layerExegetical) { readStudyThumb }
                practiceCard(.paper, accent: Color(hex: "#8A7A5A")) { paperThumb }
            }
            .frame(maxWidth: 480)
            .padding(.horizontal, 40)
            .padding(.top, 38)

            Spacer()

            Button {
                readingModeRaw = selection.rawValue
                hasChosenPractice = true
            } label: {
                Text("Begin — \(selection.displayName)")
                    .font(AppFont.uiBody)
                    .fontWeight(.medium)
                    .foregroundStyle(Color(hex: "#FAF8F5"))
                    .frame(maxWidth: 480, minHeight: 52)
                    .background(RoundedRectangle(cornerRadius: 12).fill(AppColor.inkSurface))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#F7F4EE").ignoresSafeArea())
    }

    private func practiceCard<Thumb: View>(
        _ mode: ReadingMode,
        accent: Color,
        @ViewBuilder thumb: () -> Thumb
    ) -> some View {
        let selected = selection == mode
        return Button {
            selection = mode
        } label: {
            HStack(spacing: 16) {
                thumb()
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(mode.displayName)
                            .font(Font.custom("CrimsonText-Regular", size: 19, relativeTo: .headline))
                            .foregroundStyle(AppColor.textPrimary)
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(accent)
                        }
                    }
                    Text(mode.blurb)
                        .font(.caption)
                        .foregroundStyle(AppColor.textMuted)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "#FBFAF7")))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        selected ? accent : Color(hex: "#E3DED4"),
                        lineWidth: selected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    /// Mini page with a note dot and text lines, one highlighted.
    private var readStudyThumb: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Spacer()
                Circle().fill(AppColor.layerExegetical).frame(width: 4, height: 4)
            }
            Capsule().fill(AppColor.marginNumber).frame(height: 2)
            Capsule().fill(AppColor.marginNumber).frame(width: 40, height: 2)
            Capsule().fill(Color(hex: "#EBC96B")).frame(height: 2)
            Capsule().fill(AppColor.marginNumber).frame(width: 34, height: 2)
        }
        .padding(9)
        .frame(width: 66, height: 80, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 8).fill(AppColor.background))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(hex: "#EAE5DC"), lineWidth: 1))
    }

    /// Mini ruled page with a scrawl and a marker swipe.
    private var paperThumb: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 9) {
                ForEach(0..<7, id: \.self) { _ in
                    Rectangle().fill(Color(hex: "#ECE6D7")).frame(height: 0.6)
                }
            }
            .padding(.top, 12)
            Text("enough")
                .font(Font.custom("CrimsonText-Italic", size: 13))
                .foregroundStyle(Color(hex: "#2F4A7A"))
                .rotationEffect(.degrees(-4))
                .offset(x: 8, y: 24)
            Capsule().fill(Color(hex: "#BFE3A6").opacity(0.67))
                .frame(width: 34, height: 6)
                .offset(x: 10, y: 44)
        }
        .frame(width: 66, height: 80)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: "#FCFBF7")))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(hex: "#E7E0CF"), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
