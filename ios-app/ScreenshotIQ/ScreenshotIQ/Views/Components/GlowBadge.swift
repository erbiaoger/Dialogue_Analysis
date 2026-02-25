import SwiftUI

struct GlowBadge: View {
    let text: String
    var color: Color = AppTheme.Colors.neonSecondary

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, AppTheme.Spacing.sm)
            .padding(.vertical, AppTheme.Spacing.xs)
            .background(
                Capsule(style: .continuous)
                    .fill(color.opacity(0.16))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(color.opacity(0.55), lineWidth: 1)
                    )
            )
            .shadow(color: color.opacity(0.35), radius: 10, x: 0, y: 0)
    }
}
