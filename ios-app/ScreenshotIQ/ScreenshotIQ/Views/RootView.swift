import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    private enum Tab: CaseIterable {
        case importWorkbench
        case chat
        case settings

        var title: String {
            switch self {
            case .importWorkbench: return "Import"
            case .chat: return "Chat"
            case .settings: return "Settings"
            }
        }

        var icon: String {
            switch self {
            case .importWorkbench: return "square.grid.2x2.fill"
            case .chat: return "bubble.left.and.bubble.right.fill"
            case .settings: return "slider.horizontal.3"
            }
        }
    }

    @State private var selectedTab: Tab = .importWorkbench

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                ImportView()
                    .opacity(selectedTab == .importWorkbench ? 1 : 0)
                    .allowsHitTesting(selectedTab == .importWorkbench)

                ChatView()
                    .opacity(selectedTab == .chat ? 1 : 0)
                    .allowsHitTesting(selectedTab == .chat)

                SettingsView()
                    .opacity(selectedTab == .settings ? 1 : 0)
                    .allowsHitTesting(selectedTab == .settings)
            }
            .animation(.easeOut(duration: 0.16), value: selectedTab)

            HStack(spacing: AppTheme.Spacing.sm) {
                ForEach(Tab.allCases, id: \.title) { tab in
                    tabItem(tab)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.sm)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(
                        Capsule(style: .continuous)
                            .fill(AppTheme.Colors.cardBase)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        AppTheme.Colors.cardGlassTint.opacity(0.34),
                                        .clear,
                                        AppTheme.Colors.cardGlassTint.opacity(0.18),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(AppTheme.Colors.cardStroke, lineWidth: 1)
                    )
            )
            .padding(.horizontal, AppTheme.Spacing.sm)
            .padding(.bottom, AppTheme.Spacing.xs)
        }
        .appBackground()
        .preferredColorScheme(appState.themeMode.colorScheme)
    }

    private func tabItem(_ tab: Tab) -> some View {
        let selected = selectedTab == tab
        return Button {
            withAnimation(AppTheme.Motion.spring) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .scaleEffect(selected ? 1.08 : 1.0)
                    .shadow(color: selected ? AppTheme.Colors.neonPrimary.opacity(0.4) : .clear, radius: selected ? 8 : 0)
                Text(tab.title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(selected ? AppTheme.Colors.neonPrimary : AppTheme.Colors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? AppTheme.Colors.neonPrimary.opacity(0.12) : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(selected ? AppTheme.Colors.neonPrimary.opacity(0.6) : .clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
