import SwiftUI

struct NeonButton: View {
    let title: String
    let icon: String?
    let tint: Color
    let action: () -> Void

    @State private var pressed = false

    init(_ title: String, icon: String? = nil, tint: Color = AppTheme.Colors.neonPrimary, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: AppTheme.Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(AppTheme.Colors.bgPrimary)
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: tint.opacity(0.45), radius: 14, x: 0, y: 8)
            )
            .scaleEffect(pressed ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !pressed {
                        withAnimation(AppTheme.Motion.pop) { pressed = true }
                    }
                }
                .onEnded { _ in
                    withAnimation(AppTheme.Motion.pop) { pressed = false }
                }
        )
    }
}
