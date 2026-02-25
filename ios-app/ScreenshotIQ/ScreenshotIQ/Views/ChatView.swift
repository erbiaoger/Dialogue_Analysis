import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var appState: AppState
    @State private var question = ""
    @State private var selectedEvidence: Evidence?
    @State private var animateIn = false

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.md) {
                BentoCard(title: "模型状态", glow: AppTheme.Colors.neonSecondary) {
                    Text(appState.lastModelInfo)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.sm)
                .offset(y: animateIn ? 0 : 20)
                .opacity(animateIn ? 1 : 0)

                ScrollView {
                    VStack(spacing: AppTheme.Spacing.md) {
                        BentoCard(title: "对话流", glow: AppTheme.Colors.neonPrimary) {
                            if appState.messages.isEmpty {
                                Text("导入截图后，可继续在这里追问。")
                                    .font(AppTheme.Typography.body)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                            } else {
                                ForEach(Array(appState.messages.enumerated()), id: \.offset) { _, line in
                                    let isAnswer = line.hasPrefix("A:")
                                    HStack {
                                        if isAnswer { Spacer(minLength: 18) }
                                        Text(line)
                                            .font(AppTheme.Typography.body)
                                            .foregroundStyle(AppTheme.Colors.textPrimary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(AppTheme.Spacing.sm)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(AppTheme.Colors.cardBase)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                            .stroke(
                                                                isAnswer ? AppTheme.Colors.neonPrimary.opacity(0.48) : AppTheme.Colors.neonSecondary.opacity(0.48),
                                                                lineWidth: 1
                                                            )
                                                    )
                                                    .shadow(
                                                        color: (isAnswer ? AppTheme.Colors.neonPrimary : AppTheme.Colors.neonSecondary).opacity(0.2),
                                                        radius: 10
                                                    )
                                            )
                                        if !isAnswer { Spacer(minLength: 18) }
                                    }
                                }
                            }
                        }

                        BentoCard(title: "证据引用", glow: AppTheme.Colors.neonSecondary) {
                            if appState.citations.isEmpty {
                                Text("暂无引用")
                                    .font(AppTheme.Typography.body)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                            } else {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
                                    ForEach(appState.citations) { c in
                                        Button {
                                            Task {
                                                guard let sessionID = appState.sessionID else { return }
                                                selectedEvidence = try? await appState.api.fetchEvidence(sessionID: sessionID, evidenceID: c.evidenceId)
                                            }
                                        } label: {
                                            VStack(alignment: .leading, spacing: 6) {
                                                GlowBadge(text: c.reasoningRole, color: AppTheme.Colors.neonSecondary)
                                                Text("score \(String(format: "%.2f", c.score))")
                                                    .font(AppTheme.Typography.monoNumber)
                                                    .foregroundStyle(AppTheme.Colors.textPrimary)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(AppTheme.Spacing.sm)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(AppTheme.Colors.cardBase)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                            .stroke(AppTheme.Colors.cardStroke, lineWidth: 1)
                                                    )
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        BentoCard(title: "建议追问", glow: AppTheme.Colors.neonSecondary) {
                            if appState.followups.isEmpty {
                                Text("暂无追问建议")
                                    .font(AppTheme.Typography.body)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                            } else {
                                ForEach(appState.followups, id: \.self) { followup in
                                    Text("• \(followup)")
                                        .font(AppTheme.Typography.body)
                                        .foregroundStyle(AppTheme.Colors.textPrimary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.bottom, AppTheme.Spacing.sm)
                }

                HStack(spacing: AppTheme.Spacing.sm) {
                    TextField("继续追问", text: $question)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AppTheme.Colors.cardBase)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(AppTheme.Colors.cardStroke, lineWidth: 1)
                                )
                        )

                    NeonButton("发送", icon: "paperplane.fill", tint: AppTheme.Colors.neonPrimary) {
                        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !q.isEmpty else { return }
                        question = ""
                        Task { await appState.ask(q) }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.bottom, 96)
            }
            .navigationTitle("Chat")
            .appBackground()
            .sheet(item: $selectedEvidence) { evidence in
                EvidenceSheetView(evidence: evidence)
            }
            .onAppear {
                withAnimation(AppTheme.Motion.cardIn.delay(0.05)) {
                    animateIn = true
                }
            }
        }
    }
}
