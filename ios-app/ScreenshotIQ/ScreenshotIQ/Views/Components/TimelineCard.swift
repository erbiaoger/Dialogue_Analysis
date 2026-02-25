import SwiftUI

struct TimelineCard: View {
    let items: [String]
    @Binding var expanded: Bool

    @State private var phase: CGFloat = -1

    var body: some View {
        BentoCard(title: "流程时间线", glow: AppTheme.Colors.neonSecondary) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                HStack {
                    GlowBadge(text: expanded ? "已展开" : "已折叠")
                    Spacer()
                    Button(expanded ? "收起" : "展开") {
                        withAnimation(AppTheme.Motion.spring) { expanded.toggle() }
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.neonSecondary)
                }

                if expanded {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                            Text("• \(item)")
                                .font(AppTheme.Typography.body)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } else {
                    Text(items.last ?? "等待导入后开始分析")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
            .overlay(alignment: .topLeading) {
                GeometryReader { geo in
                    let w = max(120, geo.size.width * 0.36)
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.clear, AppTheme.Colors.neonSecondary.opacity(0.7), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: w, height: 3)
                        .offset(x: (geo.size.width + w) * phase - w, y: -8)
                }
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                phase = 1.2
            }
        }
    }
}
