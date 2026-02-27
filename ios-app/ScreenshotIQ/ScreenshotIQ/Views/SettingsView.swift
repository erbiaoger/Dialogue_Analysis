import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var animateIn = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.md) {
                    BentoCard(title: "外观", glow: AppTheme.Colors.neonPrimary) {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            Text("界面模式")
                                .font(AppTheme.Typography.cardTitle)
                                .foregroundStyle(AppTheme.Colors.textSecondary)

                            Picker("界面模式", selection: $appState.themeMode) {
                                ForEach(ThemeMode.allCases) { mode in
                                    Text(mode.title).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .offset(y: animateIn ? 0 : 12)
                    .opacity(animateIn ? 1 : 0)

                    BentoCard(title: "隐私", glow: AppTheme.Colors.neonSecondary) {
                        Text("默认开启云端处理，用于截图理解与对话推理。你可随时清理会话数据。")
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    }
                    .offset(y: animateIn ? 0 : 16)
                    .opacity(animateIn ? 1 : 0)

                    BentoCard(title: "模型", glow: AppTheme.Colors.neonPrimary) {
                        Text("默认自动路由：简单问题走低成本模型，复杂问题走高能力模型。")
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    }
                    .offset(y: animateIn ? 0 : 22)
                    .opacity(animateIn ? 1 : 0)

                    BentoCard(title: "API", glow: AppTheme.Colors.neonSecondary) {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            TextField("API Base URL", text: $appState.apiBaseURL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                                .font(AppTheme.Typography.body)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                                .padding(.horizontal, AppTheme.Spacing.sm)
                                .padding(.vertical, AppTheme.Spacing.sm)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(AppTheme.Colors.bgSecondary.opacity(0.5))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(AppTheme.Colors.cardStroke, lineWidth: 1)
                                        )
                                )

                            NeonButton("恢复默认 API 地址", icon: "arrow.uturn.backward.circle", tint: AppTheme.Colors.neonSecondary) {
                                appState.resetAPIBaseURL()
                            }

                            NeonButton("测试 API 连接", icon: "dot.radiowaves.left.and.right", tint: AppTheme.Colors.neonPrimary) {
                                Task { await appState.testAPIConnection() }
                            }

                            if !appState.connectionTestStatus.isEmpty {
                                Text(appState.connectionTestStatus)
                                    .font(.system(size: 12, weight: .regular, design: .rounded))
                                    .lineLimit(nil)
                                    .multilineTextAlignment(.leading)
                                    .foregroundStyle(appState.connectionTestStatus.contains("成功") ? AppTheme.Colors.neonPrimary : AppTheme.Colors.danger)
                            }

                            Text("模拟器可用 http://127.0.0.1:8080；真机请填电脑局域网IP，例如 http://192.168.x.x:8080")
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                    }
                    .offset(y: animateIn ? 0 : 28)
                    .opacity(animateIn ? 1 : 0)

                    BentoCard(title: "自动回复", glow: AppTheme.Colors.neonPrimary) {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            Toggle("导入后自动生成建议", isOn: $appState.autoReplyEnabled)
                                .toggleStyle(.switch)
                                .tint(AppTheme.Colors.neonPrimary)
                                .foregroundStyle(AppTheme.Colors.textPrimary)

                            Text("默认 Prompt")
                                .font(AppTheme.Typography.cardTitle)
                                .foregroundStyle(AppTheme.Colors.textSecondary)

                            TextEditor(text: $appState.defaultAutoPrompt)
                                .font(AppTheme.Typography.body)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                                .frame(minHeight: 160)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 6)
                                .scrollContentBackground(.hidden)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(AppTheme.Colors.bgSecondary.opacity(0.5))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(AppTheme.Colors.cardStroke, lineWidth: 1)
                                        )
                                )

                            NeonButton("恢复默认 Prompt", icon: "wand.and.stars", tint: AppTheme.Colors.neonPrimary) {
                                appState.resetDefaultPrompt()
                            }
                        }
                    }
                    .offset(y: animateIn ? 0 : 34)
                    .opacity(animateIn ? 1 : 0)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.sm)
                .padding(.bottom, 104)
            }
            .navigationTitle("Settings")
            .scrollIndicators(.hidden)
            .appBackground()
            .onAppear {
                withAnimation(AppTheme.Motion.cardIn.delay(0.05)) {
                    animateIn = true
                }
            }
        }
    }
}
