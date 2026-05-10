import SwiftUI

struct RateScreen: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let toilet: Toilet

    @State private var rating: Int = 0
    @State private var selectedTags: Set<String> = []
    @State private var comment: String = ""
    @State private var submitting = false
    @State private var toast: String?

    private let tagKeys: [String] = [
        "clean", "spacious", "quiet", "busy",
        "english_signs", "has_paper", "dirty"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            top

            Text(state.t("ratingThisToilet"))
                .font(.zEyebrow)
                .tracking(1.4)
                .foregroundStyle(Color.zInk48)
                .frame(maxWidth: .infinity)

            Text(state.name(toilet.name))
                .font(.zSubtitle).zTight()
                .foregroundStyle(Color.zInk)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { n in
                    Button {
                        rating = n
                    } label: {
                        Image(systemName: n <= rating ? "star.fill" : "star")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(n <= rating ? Color.zWarn : Color.zInk24)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)

            Text(state.t("howWasIt"))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.zInk48)
                .frame(maxWidth: .infinity)

            tagGrid

            commentField

            Spacer()

            Button(action: submit) {
                Text(submitting ? state.t("submitting") : state.t("submit"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PillStyle(variant: .primary))
            .disabled(rating == 0 || submitting)
            .opacity(rating == 0 ? 0.4 : 1)
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .background(Color.zCanvas)
        .navigationBarBackButtonHidden(true)
        .overlay(alignment: .top) {
            if let t = toast {
                Text(t)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 18)
                    .background(Color.zInk.opacity(0.92))
                    .clipShape(Capsule())
                    .padding(.top, 70)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var top: some View {
        HStack {
            Button { dismiss() } label: {
                Text("✕").font(.system(size: 18)).foregroundStyle(Color.zInk).padding(8)
            }.buttonStyle(.plain)
            Spacer()
            Button { dismiss() } label: {
                Text(state.t("skip")).font(.system(size: 14)).foregroundStyle(Color.zPrimary).padding(8)
            }.buttonStyle(.plain)
        }
    }

    private var tagGrid: some View {
        FlowLayout(spacing: 6) {
            ForEach(tagKeys, id: \.self) { key in
                let on = selectedTags.contains(key)
                Button {
                    if on { selectedTags.remove(key) } else { selectedTags.insert(key) }
                } label: {
                    Text(state.t("tag" + key.split(separator: "_").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()))
                        .font(.system(size: 13))
                        .foregroundStyle(on ? Color.white : Color.zInk80)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(on ? Color.zInk : Color.zCanvas)
                        .overlay(Capsule().stroke(on ? Color.zInk : Color.zHairline, lineWidth: 1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var commentField: some View {
        TextField(state.t("commentPlaceholder"), text: $comment, axis: .vertical)
            .lineLimit(2...4)
            .padding(12)
            .font(.system(size: 14))
            .background(Color.zCanvas)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.zHairline, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func submit() {
        guard rating > 0 else { return }
        submitting = true
        Task {
            do {
                _ = try await SupabaseAPI.shared.submitReview(
                    toiletId: toilet.id,
                    rating: rating,
                    tags: Array(selectedTags),
                    comment: comment.isEmpty ? nil : comment,
                    language: state.language
                )
                showToast(state.t("thanks"))
                try? await Task.sleep(nanoseconds: 600_000_000)
                dismiss()
            } catch SupabaseError.rateLimited {
                showToast(state.t("rateLimit"))
                submitting = false
            } catch {
                showToast(state.t("submitFailed"))
                submitting = false
            }
        }
    }

    private func showToast(_ msg: String) {
        withAnimation { toast = msg }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation { toast = nil }
        }
    }
}

// =============================================================================
// FlowLayout — wraps children onto multiple lines when they overflow.
// =============================================================================

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0; var y: CGFloat = 0; var rowHeight: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > maxWidth { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            rowHeight = max(rowHeight, s.height)
            x += s.width + spacing
        }
        return CGSize(width: maxWidth.isFinite ? maxWidth : x, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX; var y: CGFloat = bounds.minY; var rowHeight: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: s.width, height: s.height))
            rowHeight = max(rowHeight, s.height)
            x += s.width + spacing
        }
    }
}
