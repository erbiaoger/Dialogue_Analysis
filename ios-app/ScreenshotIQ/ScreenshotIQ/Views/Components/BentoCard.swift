import SwiftUI

struct BentoCard<Content: View>: View {
    let title: String?
    let glow: Color
    let content: Content

    init(title: String? = nil, glow: Color = AppTheme.Colors.neonSecondary, @ViewBuilder content: () -> Content) {
        self.title = title
        self.glow = glow
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            if let title {
                Text(title)
                    .font(AppTheme.Typography.cardTitle)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .textCase(.uppercase)
            }
            content
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(AppTheme.Colors.cardBase)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppTheme.Colors.cardGlassTint.opacity(0.42),
                                    .clear,
                                    AppTheme.Colors.cardGlassTint.opacity(0.18),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppTheme.Colors.cardStroke, lineWidth: 1)
                )
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(glow.opacity(0.18))
                        .frame(width: 120, height: 120)
                        .blur(radius: 30)
                        .offset(x: 34, y: -28)
                }
                .shadow(color: glow.opacity(0.2), radius: 22, x: 0, y: 12)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
