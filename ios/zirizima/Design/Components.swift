import SwiftUI

// =============================================================================
// Pill — primary + ghost CTA. Capsule shape, 17pt, scale-95 on press.
// =============================================================================

struct PillStyle: ButtonStyle {
    enum Variant { case primary, ghost, dark }
    var variant: Variant = .primary
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let bg: Color
        let fg: Color
        let stroke: Color?
        switch variant {
        case .primary: bg = .zPrimary; fg = .white; stroke = nil
        case .ghost:   bg = .clear;     fg = .zPrimary; stroke = .zPrimary
        case .dark:    bg = .zInk;      fg = .white; stroke = nil
        }
        let vPad: CGFloat = compact ? 9 : 12
        let hPad: CGFloat = compact ? 16 : 22
        return configuration.label
            .font(compact ? .zCaptionBold : .zBody)
            .foregroundStyle(fg)
            .padding(.vertical, vPad)
            .padding(.horizontal, hPad)
            .frame(minHeight: compact ? 36 : 44)
            .background(bg)
            .overlay(
                Group {
                    if let stroke {
                        Capsule().stroke(stroke, lineWidth: 1)
                    }
                }
            )
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.18, dampingFraction: 0.85), value: configuration.isPressed)
    }
}

// =============================================================================
// Card — white surface with subtle border + 18pt radius.
// =============================================================================

struct ZCard<Content: View>: View {
    @ViewBuilder var content: Content
    var padding: CGFloat = 18
    var body: some View {
        content
            .padding(padding)
            .background(Color.zCanvas)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.04), lineWidth: 1)
            )
    }
}

// =============================================================================
// Badge — small pill chip used for accessibility / 24h / EN flags.
// =============================================================================

struct ZBadge: View {
    let text: String
    var icon: String? = nil
    var body: some View {
        HStack(spacing: 4) {
            if let icon { Text(icon) }
            Text(text)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(Color.zInk80)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.zParchment)
        .clipShape(Capsule())
    }
}

// =============================================================================
// Star row — fills `rating` filled stars + remaining hollow.
// =============================================================================

struct StarsView: View {
    let rating: Double
    var size: CGFloat = 13
    var body: some View {
        let full = max(0, min(5, Int(rating.rounded())))
        HStack(spacing: 1) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: i < full ? "star.fill" : "star")
                    .font(.system(size: size, weight: .regular))
                    .foregroundStyle(i < full ? Color.zWarn : Color.zInk24)
            }
        }
    }
}

// =============================================================================
// Filter chip — toggleable round pill.
// =============================================================================

struct FilterChip: View {
    let label: String
    let on: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(on ? Color.white : Color.zInk80)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(on ? Color.zInk : Color.zCanvas)
                .overlay(Capsule().stroke(on ? Color.zInk : Color.zHairline, lineWidth: 1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// =============================================================================
// iOS-style toggle that's slightly more compact than the system toggle.
// =============================================================================

struct ZToggle: View {
    @Binding var isOn: Bool
    var body: some View {
        Toggle("", isOn: $isOn)
            .labelsHidden()
            .tint(.green)
    }
}

// =============================================================================
// Hairline divider
// =============================================================================

struct Hairline: View {
    var color: Color = .zDivider
    var body: some View {
        Rectangle().fill(color).frame(height: 1)
    }
}
