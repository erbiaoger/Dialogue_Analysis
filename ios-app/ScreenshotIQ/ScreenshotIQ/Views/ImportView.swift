import SwiftUI
import PhotosUI
import UIKit

struct ImportView: View {
    @EnvironmentObject private var appState: AppState
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var evidenceExpanded = false
    @State private var timelineExpanded = false
    @State private var animateIn = false
    @State private var selectedReplyIndex = 0

    private var lowPowerMode: Bool { ProcessInfo.processInfo.isLowPowerModeEnabled }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.md) {
                    importActionsCard
                        .offset(y: animateIn ? 0 : 28)
                        .opacity(animateIn ? 1 : 0)

                    replyQuickCard
                        .offset(y: animateIn ? 0 : 34)
                        .opacity(animateIn ? 1 : 0)

                    speakerCard
                        .offset(y: animateIn ? 0 : 40)
                        .opacity(animateIn ? 1 : 0)

                    replyAnalysisCard
                        .offset(y: animateIn ? 0 : 44)
                        .opacity(animateIn ? 1 : 0)

                    TimelineCard(
                        items: appState.analysisTimeline.isEmpty ? ["等待导入后开始分析"] : appState.analysisTimeline,
                        expanded: $timelineExpanded
                    )
                    .offset(y: animateIn ? 0 : 46)
                    .opacity(animateIn ? 1 : 0)

                    evidenceCard
                        .offset(y: animateIn ? 0 : 52)
                        .opacity(animateIn ? 1 : 0)

                    importedImagesCard
                        .offset(y: animateIn ? 0 : 58)
                        .opacity(animateIn ? 1 : 0)

                    heroCard
                        .offset(y: animateIn ? 0 : 22)
                        .opacity(animateIn ? 1 : 0)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.sm)
                .padding(.bottom, 110)
            }
            .navigationTitle("Import")
            .scrollIndicators(.hidden)
            .appBackground()
            .onAppear {
                withAnimation(AppTheme.Motion.cardIn.delay(lowPowerMode ? 0 : 0.05)) {
                    animateIn = true
                }
            }
            .onChange(of: pickerItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                Task {
                    var images: [UIImage] = []
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            images.append(image)
                        }
                    }
                    await appState.importScreenshots(images, source: "photo-library")
                    pickerItems = []
                }
            }
            .onChange(of: appState.latestReplyOptions.count) { _, newCount in
                if newCount == 0 {
                    selectedReplyIndex = 0
                } else if selectedReplyIndex >= newCount {
                    selectedReplyIndex = 0
                }
            }
        }
    }

    private var heroCard: some View {
        BentoCard(title: "导入工作台", glow: stageColor(appState.importStage)) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                        Text(stageText(appState.importStage))
                            .font(AppTheme.Typography.hero)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .shadow(color: stageColor(appState.importStage).opacity(0.2), radius: 10)
                        Text(appState.importStatus)
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                    Spacer()
                    GlowBadge(text: "进度 \(Int(appState.importProgressPhase * 100))%", color: stageColor(appState.importStage))
                }

                GeometryReader { geo in
                    let width = max(0, geo.size.width * appState.importProgressPhase)
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(AppTheme.Colors.textSecondary.opacity(0.18))
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [stageColor(appState.importStage), AppTheme.Colors.neonSecondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: width)
                            .shadow(color: stageColor(appState.importStage).opacity(0.45), radius: 10)
                    }
                    .frame(height: 8)
                }
                .frame(height: 8)

                HStack {
                    Text(appState.lastModelInfo)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .lineLimit(2)
                    Spacer()
                    if appState.importStage == .failed {
                        NeonButton("重试", icon: "arrow.clockwise", tint: AppTheme.Colors.danger) {
                            Task { await appState.retryAutoGenerate() }
                        }
                    }
                }
            }
        }
    }

    private var importActionsCard: some View {
        BentoCard(glow: AppTheme.Colors.neonPrimary) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.neonPrimary)
                    Text("导入截图")
                        .font(AppTheme.Typography.title)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                }

                HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                    Text("选择截图后自动分析")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    Spacer()
                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: 10,
                        matching: .screenshots,
                        photoLibrary: .shared()
                    ) {
                        Label("选择截图", systemImage: "photo.on.rectangle.angled")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.Colors.bgPrimary)
                            .padding(.horizontal, AppTheme.Spacing.md)
                            .padding(.vertical, AppTheme.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [AppTheme.Colors.neonPrimary, AppTheme.Colors.neonPrimary.opacity(0.78)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: AppTheme.Colors.neonPrimary.opacity(0.4), radius: 10, x: 0, y: 6)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .frame(minHeight: 52, alignment: .center)
            }
        }
    }

    private var speakerCard: some View {
        BentoCard(title: "分人理解", glow: AppTheme.Colors.neonSecondary) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                if appState.latestSpeakerSplit == nil && appState.latestIntentOther.isEmpty && appState.latestIntentSelf.isEmpty {
                    Text("导入后会自动按左=对方、右=我进行分人理解")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                } else {
                    if let split = appState.latestSpeakerSplit {
                        HStack {
                            GlowBadge(text: "左=对方，右=我", color: AppTheme.Colors.neonSecondary)
                            GlowBadge(text: "置信度 \(String(format: "%.2f", split.confidence))", color: split.confidence > 0.5 ? AppTheme.Colors.neonPrimary : AppTheme.Colors.danger)
                        }
                        if split.confidence <= 0.5 {
                            Text(split.lowConfidenceReason ?? "分人可能不准，已按默认规则推断")
                                .font(AppTheme.Typography.body)
                                .foregroundStyle(AppTheme.Colors.danger)
                        }
                        splitBlock(title: "对方说了什么", lines: split.otherLines, glow: AppTheme.Colors.neonSecondary)
                        splitBlock(title: "我说了什么", lines: split.selfLines, glow: AppTheme.Colors.neonPrimary)
                    }

                    if !appState.latestIntentOther.isEmpty {
                        insightText(title: "对方意思", value: appState.latestIntentOther, glow: AppTheme.Colors.neonSecondary)
                    }
                    if !appState.latestIntentSelf.isEmpty {
                        insightText(title: "我方意思", value: appState.latestIntentSelf, glow: AppTheme.Colors.neonPrimary)
                    }
                }
            }
        }
    }

    private var replyQuickCard: some View {
        BentoCard(title: "回复", glow: AppTheme.Colors.neonPrimary) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                if appState.latestInsightAnswer.isEmpty {
                    Text("导入后会自动生成可复制回复")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                } else {
                    if !appState.latestReplyOptions.isEmpty {
                        HStack(spacing: AppTheme.Spacing.xs) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppTheme.Spacing.xs) {
                                    ForEach(Array(appState.latestReplyOptions.enumerated()), id: \.offset) { index, option in
                                        Button {
                                            withAnimation(AppTheme.Motion.spring) {
                                                selectedReplyIndex = index
                                            }
                                        } label: {
                                            Text("\(option.style)版")
                                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                .foregroundStyle(selectedReplyIndex == index ? AppTheme.Colors.bgPrimary : AppTheme.Colors.neonSecondary)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(
                                                    Capsule(style: .continuous)
                                                        .fill(selectedReplyIndex == index ? AppTheme.Colors.neonSecondary : AppTheme.Colors.neonSecondary.opacity(0.12))
                                                        .overlay(
                                                            Capsule(style: .continuous)
                                                                .stroke(AppTheme.Colors.neonSecondary.opacity(0.5), lineWidth: 1)
                                                        )
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            if let current = currentReplyOption {
                                SmallCopyButton(title: "复制", tint: AppTheme.Colors.neonSecondary) {
                                    UIPasteboard.general.string = current.text
                                }
                            }
                        }

                        if let current = currentReplyOption {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                                Text(current.text)
                                    .font(AppTheme.Typography.body)
                                    .foregroundStyle(AppTheme.Colors.textPrimary)
                                    .textSelection(.enabled)
                                    .padding(AppTheme.Spacing.sm)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(AppTheme.Colors.neonSecondary.opacity(0.08))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .stroke(AppTheme.Colors.neonSecondary.opacity(0.45), lineWidth: 1)
                                            )
                                    )
                            }
                        }
                    }

                    if !appState.latestBestReply.isEmpty {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                            HStack {
                                Text("推荐发送")
                                    .font(AppTheme.Typography.cardTitle)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                                Spacer()
                                SmallCopyButton(title: "复制", tint: AppTheme.Colors.neonPrimary) {
                                    UIPasteboard.general.string = appState.latestBestReply
                                }
                            }
                            Text(appState.latestBestReply)
                                .font(AppTheme.Typography.body)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                                .textSelection(.enabled)
                        }
                    }
                    if !appState.latestWhy.isEmpty {
                        insightText(title: "推荐理由", value: appState.latestWhy, glow: AppTheme.Colors.neonSecondary.opacity(0.7))
                    }
                }
            }
        }
    }

    private var replyAnalysisCard: some View {
        BentoCard(title: "回复分析", glow: AppTheme.Colors.neonSecondary.opacity(0.8)) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                if let analysis = appState.latestAnalysis {
                    insightText(title: "情绪判断", value: analysis.emotion, glow: AppTheme.Colors.neonSecondary.opacity(0.8))
                    insightText(title: "核心诉求", value: analysis.coreNeed, glow: AppTheme.Colors.neonSecondary.opacity(0.8))
                    insightText(title: "风险点", value: analysis.riskPoint, glow: AppTheme.Colors.danger.opacity(0.8))
                    SmallCopyButton(title: "复制完整结果", tint: AppTheme.Colors.neonPrimary) {
                        UIPasteboard.general.string = appState.latestInsightAnswer
                    }
                } else {
                    Text("导入后会显示情绪、诉求和风险点分析")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
        }
    }

    private var currentReplyOption: ReplyOption? {
        guard !appState.latestReplyOptions.isEmpty else { return nil }
        let safeIndex = min(max(0, selectedReplyIndex), appState.latestReplyOptions.count - 1)
        return appState.latestReplyOptions[safeIndex]
    }

    private var evidenceCard: some View {
        BentoCard(title: "证据入口", glow: AppTheme.Colors.neonSecondary) {
            if appState.citations.isEmpty {
                Text("暂无可展示依据")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            } else {
                DisclosureGroup("查看依据（\(appState.citations.count)）", isExpanded: $evidenceExpanded) {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        if appState.evidenceItems.isEmpty {
                            Text("正在加载依据详情...")
                                .font(AppTheme.Typography.body)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        } else {
                            ForEach(appState.evidenceItems) { evidence in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(evidence.excerpt)
                                        .font(AppTheme.Typography.body)
                                        .foregroundStyle(AppTheme.Colors.textPrimary)
                                        .textSelection(.enabled)
                                    Text("image_id: \(evidence.imageId)")
                                        .font(.system(size: 11, weight: .regular, design: .rounded))
                                        .foregroundStyle(AppTheme.Colors.textSecondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .padding(.top, AppTheme.Spacing.xs)
                }
                .tint(AppTheme.Colors.neonSecondary)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            }
        }
    }

    private var importedImagesCard: some View {
        BentoCard(title: "已导入截图", glow: AppTheme.Colors.neonSecondary) {
            if appState.importedScreenshots.isEmpty {
                Text("暂无截图")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        ForEach(appState.importedScreenshots) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                Image(uiImage: item.image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                Text(item.imageID)
                                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                                    .lineLimit(1)
                                Text(item.source)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(AppTheme.Colors.neonSecondary)
                            }
                            .frame(width: 120, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    private func splitBlock(title: String, lines: [String], glow: Color) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text(title)
                .font(AppTheme.Typography.cardTitle)
                .foregroundStyle(glow)
            if lines.isEmpty {
                Text("证据不足")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            } else {
                Text(lines.joined(separator: "\n"))
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(glow.opacity(0.09))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(glow.opacity(0.48), lineWidth: 1)
                )
                .shadow(color: glow.opacity(0.18), radius: 10)
        )
    }

    private func insightText(title: String, value: String, glow: Color) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
            Text("\(title)：")
                .font(AppTheme.Typography.cardTitle)
                .foregroundStyle(glow)
            Text(value)
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(glow.opacity(0.09))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(glow.opacity(0.48), lineWidth: 1)
                )
                .shadow(color: glow.opacity(0.16), radius: 8)
        )
    }

    private func buildSpeakerSummary() -> String {
        var lines: [String] = []
        if let split = appState.latestSpeakerSplit {
            lines.append("分人规则: 左=对方，右=我")
            if !split.otherLines.isEmpty { lines.append("对方说了什么:\n\(split.otherLines.joined(separator: "\n"))") }
            if !split.selfLines.isEmpty { lines.append("我说了什么:\n\(split.selfLines.joined(separator: "\n"))") }
        }
        if !appState.latestIntentOther.isEmpty {
            lines.append("对方意思:\n\(appState.latestIntentOther)")
        }
        if !appState.latestIntentSelf.isEmpty {
            lines.append("我方意思:\n\(appState.latestIntentSelf)")
        }
        return lines.joined(separator: "\n\n")
    }

    private func stageColor(_ stage: ImportStage) -> Color {
        switch stage {
        case .idle: return AppTheme.Colors.textSecondary
        case .importing: return AppTheme.Colors.neonSecondary
        case .analyzing: return AppTheme.Colors.neonPrimary
        case .generating: return AppTheme.Colors.neonPrimary
        case .ready: return AppTheme.Colors.neonPrimary
        case .failed: return AppTheme.Colors.danger
        }
    }

    private func stageText(_ stage: ImportStage) -> String {
        switch stage {
        case .idle: return "空闲"
        case .importing: return "导入中"
        case .analyzing: return "分析中"
        case .generating: return "生成中"
        case .ready: return "已完成"
        case .failed: return "失败"
        }
    }
}

private struct SmallCopyButton: View {
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button {
            HapticFeedback.copySuccess()
            action()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(tint.opacity(0.45), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
