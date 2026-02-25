import Foundation
import SwiftUI
import Combine
import UIKit

enum ThemeMode: String, CaseIterable, Identifiable {
    case dark
    case light
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dark: return "夜晚"
        case .light: return "白天"
        case .system: return "跟随系统"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    static let defaultPromptTemplate = "请先按左=对方、右=我分开理解：1) 对方说了什么，2) 我说了什么，3) 对方意思，4) 我方意思；再输出5) 情绪判断，6) 核心诉求，7) 风险点，8) 三种高情商回复版本（温和/坚定/幽默），9) 推荐发送版本与理由。每条回复必须简短、可直接复制。"
    static let defaultAPIBaseURL = APIClient.defaultBaseURLString

    @Published var sessionID: String?
    @Published var importStage: ImportStage = .idle
    @Published var importErrorMessage: String?

    @Published var selectedImageIDs: [String] = []
    @Published var importedScreenshots: [ImportedScreenshot] = []

    @Published var messages: [String] = []
    @Published var citations: [Citation] = []
    @Published var evidenceItems: [Evidence] = []
    @Published var followups: [String] = []

    @Published var importStatus: String = "未导入截图"
    @Published var lastModelInfo: String = "模型: 未请求"
    @Published var analysisTimeline: [String] = []
    @Published var isAnimatingImportPulse: Bool = false
    @Published var importProgressPhase: Double = 0

    @Published var latestInsightQuestion: String = ""
    @Published var latestInsightAnswer: String = ""
    @Published var latestAnalysis: ConversationAnalysis?
    @Published var latestSpeakerSplit: SpeakerSplit?
    @Published var latestIntentOther: String = ""
    @Published var latestIntentSelf: String = ""
    @Published var latestReplyOptions: [ReplyOption] = []
    @Published var latestBestReply: String = ""
    @Published var latestWhy: String = ""

    @Published var autoReplyEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoReplyEnabled, forKey: autoReplyEnabledKey)
        }
    }

    @Published var apiBaseURL: String {
        didSet {
            APIClient.saveBaseURL(apiBaseURL)
        }
    }

    @Published var defaultAutoPrompt: String {
        didSet {
            UserDefaults.standard.set(defaultAutoPrompt, forKey: defaultPromptKey)
        }
    }
    @Published var connectionTestStatus: String = ""

    @Published var themeMode: ThemeMode {
        didSet {
            UserDefaults.standard.set(themeMode.rawValue, forKey: themeModeKey)
        }
    }

    let api = APIClient()
    private let defaultPromptKey = "default_auto_prompt"
    private let autoReplyEnabledKey = "default_auto_reply_enabled"
    private let themeModeKey = "ui_theme_mode"

    init() {
        self.apiBaseURL = APIClient.currentBaseURLString()
        self.autoReplyEnabled = UserDefaults.standard.object(forKey: autoReplyEnabledKey) as? Bool ?? true
        self.defaultAutoPrompt = UserDefaults.standard.string(forKey: defaultPromptKey)
            ?? AppState.defaultPromptTemplate
        let storedTheme = UserDefaults.standard.string(forKey: themeModeKey)
        self.themeMode = ThemeMode(rawValue: storedTheme ?? "") ?? .dark
    }

    func resetDefaultPrompt() {
        defaultAutoPrompt = AppState.defaultPromptTemplate
    }

    func resetAPIBaseURL() {
        apiBaseURL = AppState.defaultAPIBaseURL
        APIClient.saveBaseURL(apiBaseURL)
    }

    func testAPIConnection() async {
        connectionTestStatus = "测试中..."
        do {
            try await api.healthCheck()
            connectionTestStatus = "连接成功：/healthz 正常"
        } catch {
            connectionTestStatus = "连接失败：\(error.localizedDescription)"
        }
    }

    private func pushTimeline(_ item: String) {
        let ts = Self.timeStampString()
        analysisTimeline.append("[\(ts)] \(item)")
        if analysisTimeline.count > 40 {
            analysisTimeline.removeFirst(analysisTimeline.count - 40)
        }
    }

    private static func timeStampString() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: Date())
    }

    private func setStage(_ stage: ImportStage, status: String, error: String? = nil) {
        importStage = stage
        importStatus = status
        importErrorMessage = error
        switch stage {
        case .idle:
            importProgressPhase = 0
            isAnimatingImportPulse = false
        case .importing:
            importProgressPhase = 0.2
            isAnimatingImportPulse = true
        case .analyzing:
            importProgressPhase = 0.55
            isAnimatingImportPulse = true
        case .generating:
            importProgressPhase = 0.82
            isAnimatingImportPulse = true
        case .ready:
            importProgressPhase = 1.0
            isAnimatingImportPulse = false
        case .failed:
            importProgressPhase = 1.0
            isAnimatingImportPulse = false
        }
    }

    func bootstrapSessionIfNeeded() async {
        guard sessionID == nil else { return }
        do {
            sessionID = try await api.createSession(deviceID: UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString)
        } catch {
            setStage(.failed, status: "创建会话失败", error: error.localizedDescription)
            pushTimeline("创建会话失败：\(error.localizedDescription)")
        }
    }

    private func clearInsightResult() {
        latestInsightQuestion = ""
        latestInsightAnswer = ""
        latestAnalysis = nil
        latestSpeakerSplit = nil
        latestIntentOther = ""
        latestIntentSelf = ""
        latestReplyOptions = []
        latestBestReply = ""
        latestWhy = ""
        citations = []
        evidenceItems = []
        followups = []
    }

    private func updateModelInfo(model: String?, llmError: String?) {
        if let model, !model.isEmpty {
            lastModelInfo = "模型: \(model)"
        } else {
            lastModelInfo = "模型: fallback/local"
        }

        if let llmError, !llmError.isEmpty {
            lastModelInfo += " (LLM错误: \(llmError.prefix(120)))"
        }
    }

    private func refreshEvidenceItems(sessionID: String, citations: [Citation]) async {
        let limit = Array(citations.prefix(6))
        if limit.isEmpty {
            evidenceItems = []
            return
        }
        var loaded: [Evidence] = []
        for citation in limit {
            if let item = try? await api.fetchEvidence(sessionID: sessionID, evidenceID: citation.evidenceId) {
                loaded.append(item)
            }
        }
        evidenceItems = loaded
    }

    private func streamText(
        _ full: String,
        minChunkSize: Int = 14,
        maxUpdates: Int = 16,
        delayMs: UInt64 = 6,
        update: (String) -> Void
    ) async {
        let text = full.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            update("")
            return
        }
        let desiredChunk = Int(ceil(Double(text.count) / Double(max(1, maxUpdates))))
        let chunkSize = max(minChunkSize, desiredChunk)

        var current = ""
        var idx = text.startIndex
        while idx < text.endIndex {
            let next = text.index(idx, offsetBy: chunkSize, limitedBy: text.endIndex) ?? text.endIndex
            current += String(text[idx..<next])
            update(current)
            idx = next
            if idx < text.endIndex {
                try? await Task.sleep(nanoseconds: delayMs * 1_000_000)
            }
        }
        update(text)
    }

    private func streamStructuredResponse(_ resp: ChatResponse) async {
        latestSpeakerSplit = nil
        latestIntentOther = ""
        latestIntentSelf = ""
        latestAnalysis = nil
        latestReplyOptions = []
        latestBestReply = ""
        latestWhy = ""
        latestInsightAnswer = ""

        if let split = resp.speakerSplit {
            latestSpeakerSplit = SpeakerSplit(
                otherLines: [],
                selfLines: [],
                mappingRule: split.mappingRule,
                confidence: split.confidence,
                lowConfidenceReason: split.lowConfidenceReason
            )

            for line in split.otherLines {
                guard let current = latestSpeakerSplit else { break }
                var other = current.otherLines
                other.append(line)
                latestSpeakerSplit = SpeakerSplit(
                    otherLines: other,
                    selfLines: current.selfLines,
                    mappingRule: current.mappingRule,
                    confidence: current.confidence,
                    lowConfidenceReason: current.lowConfidenceReason
                )
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
            for line in split.selfLines {
                guard let current = latestSpeakerSplit else { break }
                var mine = current.selfLines
                mine.append(line)
                latestSpeakerSplit = SpeakerSplit(
                    otherLines: current.otherLines,
                    selfLines: mine,
                    mappingRule: current.mappingRule,
                    confidence: current.confidence,
                    lowConfidenceReason: current.lowConfidenceReason
                )
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
        }

        if let intent = resp.intent {
            await streamText(intent.otherIntent, minChunkSize: 18, maxUpdates: 10, delayMs: 6) { latestIntentOther = $0 }
            try? await Task.sleep(nanoseconds: 25_000_000)
            await streamText(intent.selfIntent, minChunkSize: 18, maxUpdates: 10, delayMs: 6) { latestIntentSelf = $0 }
        }

        if let analysis = resp.analysis {
            latestAnalysis = ConversationAnalysis(emotion: "", coreNeed: "", riskPoint: "")
            await streamText(analysis.emotion, minChunkSize: 18, maxUpdates: 10, delayMs: 6) {
                latestAnalysis = ConversationAnalysis(
                    emotion: $0,
                    coreNeed: latestAnalysis?.coreNeed ?? "",
                    riskPoint: latestAnalysis?.riskPoint ?? ""
                )
            }
            await streamText(analysis.coreNeed, minChunkSize: 18, maxUpdates: 10, delayMs: 6) {
                latestAnalysis = ConversationAnalysis(
                    emotion: latestAnalysis?.emotion ?? "",
                    coreNeed: $0,
                    riskPoint: latestAnalysis?.riskPoint ?? ""
                )
            }
            await streamText(analysis.riskPoint, minChunkSize: 18, maxUpdates: 10, delayMs: 6) {
                latestAnalysis = ConversationAnalysis(
                    emotion: latestAnalysis?.emotion ?? "",
                    coreNeed: latestAnalysis?.coreNeed ?? "",
                    riskPoint: $0
                )
            }
        }

        for (index, option) in resp.replyOptions.enumerated() {
            latestReplyOptions.append(ReplyOption(style: option.style, text: ""))
            await streamText(option.text, minChunkSize: 20, maxUpdates: 10, delayMs: 5) { partial in
                guard latestReplyOptions.indices.contains(index) else { return }
                latestReplyOptions[index] = ReplyOption(style: option.style, text: partial)
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        if let bestReply = resp.bestReply {
            await streamText(bestReply, minChunkSize: 20, maxUpdates: 10, delayMs: 5) { latestBestReply = $0 }
        }
        if let why = resp.why {
            await streamText(why, minChunkSize: 20, maxUpdates: 10, delayMs: 5) { latestWhy = $0 }
        }

        await streamText(resp.answer, minChunkSize: 24, maxUpdates: 12, delayMs: 4) { latestInsightAnswer = $0 }
    }

    func ask(_ question: String, source: String = "manual", imageIDsOverride: [String]? = nil) async {
        guard let sessionID else {
            setStage(.failed, status: "会话不可用", error: "session_id 缺失")
            return
        }

        if source == "auto-import" {
            setStage(.generating, status: "正在生成回复建议...")
            pushTimeline("开始调用大模型生成建议")
        }

        do {
            let contextImageIDs = imageIDsOverride ?? selectedImageIDs
            let resp = try await api.sendMessage(sessionID: sessionID, message: question, imageIDs: contextImageIDs, mode: "hq_reply")
            messages.append("Q: \(question)")
            messages.append("A: ")

            citations = resp.citations
            followups = resp.followups
            latestInsightQuestion = question

            await streamStructuredResponse(resp)
            if let lastIndex = messages.indices.last {
                messages[lastIndex] = "A: \(resp.answer)"
            }

            updateModelInfo(model: resp.model, llmError: resp.llmError)
            await refreshEvidenceItems(sessionID: sessionID, citations: resp.citations)

            if source == "auto-import" {
                if !resp.analysisSteps.isEmpty {
                    resp.analysisSteps.forEach { pushTimeline($0) }
                }
                pushTimeline("已生成回复建议")
                setStage(.ready, status: "已生成回复建议（已在当前页展示）")
            }
        } catch {
            if source == "auto-import" {
                setStage(.failed, status: "自动生成失败", error: error.localizedDescription)
                pushTimeline("自动生成失败：\(error.localizedDescription)")
            } else {
                messages.append("A: 请求失败 \(error.localizedDescription)")
            }
            lastModelInfo = "模型请求失败"
        }
    }

    func retryAutoGenerate() async {
        guard !selectedImageIDs.isEmpty else {
            setStage(.failed, status: "没有可重试的截图", error: "请先导入截图")
            return
        }
        await bootstrapSessionIfNeeded()
        guard let sessionID else { return }

        setStage(.analyzing, status: "正在重试分析...")
        pushTimeline("用户触发重试")
        do {
            try await api.analyze(sessionID: sessionID, imageIDs: selectedImageIDs)
            pushTimeline("重试分析完成")
            let prompt = defaultAutoPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            if prompt.isEmpty {
                setStage(.failed, status: "默认Prompt为空", error: "请在设置中填写默认Prompt")
                return
            }
            await ask(prompt, source: "auto-import")
        } catch {
            setStage(.failed, status: "重试分析失败", error: error.localizedDescription)
            pushTimeline("重试分析失败：\(error.localizedDescription)")
        }
    }

    func importScreenshots(_ images: [UIImage], source: String, allowSessionRecovery: Bool = true) async {
        guard !images.isEmpty else { return }
        await bootstrapSessionIfNeeded()
        guard self.sessionID != nil else { return }

        analysisTimeline.removeAll()
        clearInsightResult()

        setStage(.importing, status: "正在导入 \(images.count) 张截图...")
        pushTimeline("开始导入 \(images.count) 张截图（来源: \(source)）")

        var newIDs: [String] = []
        var uploadErrors: [String] = []
        for (idx, image) in images.enumerated() {
            do {
                guard let activeSessionID = self.sessionID else {
                    uploadErrors.append("session missing")
                    break
                }
                let imageID = try await api.registerImage(
                    sessionID: activeSessionID,
                    image: image,
                    filename: "screenshot_\(Int(Date().timeIntervalSince1970))_\(idx).jpg"
                )
                newIDs.append(imageID)
                importedScreenshots.insert(
                    ImportedScreenshot(id: UUID().uuidString, imageID: imageID, image: image, source: source),
                    at: 0
                )
                pushTimeline("第 \(idx + 1) 张上传成功")
            } catch {
                uploadErrors.append(error.localizedDescription)
                pushTimeline("第 \(idx + 1) 张上传失败：\(error.localizedDescription)")
            }
        }

        guard !newIDs.isEmpty else {
            let isSessionInvalid = uploadErrors.contains { $0.localizedCaseInsensitiveContains("session not found") }
            if allowSessionRecovery && isSessionInvalid {
                pushTimeline("检测到会话失效，正在自动重建会话并重试")
                self.sessionID = nil
                await bootstrapSessionIfNeeded()
                guard self.sessionID != nil else {
                    setStage(.failed, status: "会话恢复失败", error: "无法重建会话，请稍后重试")
                    return
                }
                await importScreenshots(images, source: source, allowSessionRecovery: false)
                return
            }
            setStage(.failed, status: "导入失败", error: "所有图片上传均失败")
            return
        }

        let merged = selectedImageIDs + newIDs
        selectedImageIDs = Array(Set(merged))

        setStage(.analyzing, status: "上传完成，正在分析截图...")
        do {
            guard let activeSessionID = self.sessionID else {
                setStage(.failed, status: "分析失败", error: "session_id 缺失")
                return
            }
            try await api.analyze(sessionID: activeSessionID, imageIDs: newIDs)
            pushTimeline("分析任务完成")
        } catch {
            setStage(.failed, status: "分析失败", error: error.localizedDescription)
            pushTimeline("分析失败：\(error.localizedDescription)")
            return
        }

        guard autoReplyEnabled else {
            setStage(.ready, status: "分析完成（自动生成已关闭）")
            return
        }

        let prompt = defaultAutoPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            setStage(.failed, status: "默认Prompt为空", error: "请在设置中配置默认Prompt")
            return
        }

        await ask(prompt, source: "auto-import", imageIDsOverride: newIDs)
        if importStage == .ready {
            pushTimeline("流程结束")
        }
    }

}
