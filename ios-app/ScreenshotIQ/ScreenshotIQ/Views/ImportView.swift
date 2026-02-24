import SwiftUI
import PhotosUI
import UIKit

struct ImportView: View {
    @EnvironmentObject private var appState: AppState
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var evidenceExpanded = false

    var body: some View {
        NavigationStack {
            Form {
                Section("导入截图") {
                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: 10,
                        matching: .screenshots,
                        photoLibrary: .shared()
                    ) {
                        Label("从相册选择截图", systemImage: "photo.on.rectangle.angled")
                    }

                    Button {
                        Task { await appState.importFromClipboardIfAvailable() }
                    } label: {
                        Label("从剪贴板导入（快捷指令可用）", systemImage: "doc.on.clipboard")
                    }
                }

                Section("导入状态") {
                    HStack {
                        Text("阶段")
                        Spacer()
                        Text(stageText(appState.importStage))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(stageColor(appState.importStage))
                    }
                    Text(appState.importStatus)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let error = appState.importErrorMessage, !error.isEmpty {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if appState.importStage == .failed {
                        Button("重试分析与生成") {
                            Task { await appState.retryAutoGenerate() }
                        }
                    }
                }

                Section("分析过程") {
                    if appState.analysisTimeline.isEmpty {
                        Text("等待导入后开始分析")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(appState.analysisTimeline.enumerated()), id: \.offset) { _, item in
                            Text("• \(item)")
                                .font(.footnote)
                        }
                    }
                }

                Section("高情商回复结果") {
                    if appState.latestInsightAnswer.isEmpty {
                        Text("导入后会在这里自动生成建议")
                            .foregroundStyle(.secondary)
                    } else {
                        if let analysis = appState.latestAnalysis {
                            InsightRow(title: "情绪判断", value: analysis.emotion)
                            InsightRow(title: "核心诉求", value: analysis.coreNeed)
                            InsightRow(title: "风险点", value: analysis.riskPoint)
                        }

                        if !appState.latestReplyOptions.isEmpty {
                            Text("回复候选")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ForEach(appState.latestReplyOptions) { option in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("\(option.style)版")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Text(option.text)
                                        .font(.body)
                                        .textSelection(.enabled)
                                    Button("复制\(option.style)版") {
                                        UIPasteboard.general.string = option.text
                                    }
                                    .font(.caption)
                                }
                                .padding(.vertical, 4)
                            }
                        }

                        if !appState.latestBestReply.isEmpty {
                            Text("推荐发送")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(appState.latestBestReply)
                                .textSelection(.enabled)
                            Button("复制推荐发送") {
                                UIPasteboard.general.string = appState.latestBestReply
                            }
                            .font(.caption)
                        }

                        if !appState.latestWhy.isEmpty {
                            InsightRow(title: "推荐理由", value: appState.latestWhy)
                        }

                        Text(appState.lastModelInfo)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button("复制完整结果") {
                            UIPasteboard.general.string = appState.latestInsightAnswer
                        }
                    }
                }

                Section("证据入口") {
                    if appState.citations.isEmpty {
                        Text("暂无可展示依据")
                            .foregroundStyle(.secondary)
                    } else {
                        DisclosureGroup("查看依据（\(appState.citations.count)）", isExpanded: $evidenceExpanded) {
                            if appState.evidenceItems.isEmpty {
                                Text("正在加载依据详情...或当前模型未返回证据原文")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(appState.evidenceItems) { evidence in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(evidence.excerpt)
                                            .font(.footnote)
                                            .textSelection(.enabled)
                                        Text("image_id: \(evidence.imageId)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                    }
                }

                Section("已导入截图") {
                    if appState.importedScreenshots.isEmpty {
                        Text("暂无")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(appState.importedScreenshots) { item in
                            HStack(spacing: 12) {
                                Image(uiImage: item.image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 56, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.imageID)
                                        .font(.caption)
                                        .textSelection(.enabled)
                                    Text("source: \(item.source)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("Import")
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
        }
    }

    private func stageColor(_ stage: ImportStage) -> Color {
        switch stage {
        case .idle:
            return .secondary
        case .importing, .analyzing, .generating:
            return .orange
        case .ready:
            return .green
        case .failed:
            return .red
        }
    }

    private func stageText(_ stage: ImportStage) -> String {
        switch stage {
        case .idle:
            return "空闲"
        case .importing:
            return "导入中"
        case .analyzing:
            return "分析中"
        case .generating:
            return "生成中"
        case .ready:
            return "完成"
        case .failed:
            return "失败"
        }
    }
}

private struct InsightRow: View {
    let title: String
    let value: String

    var body: some View {
        if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body)
                    .textSelection(.enabled)
            }
            .padding(.vertical, 2)
        }
    }
}
