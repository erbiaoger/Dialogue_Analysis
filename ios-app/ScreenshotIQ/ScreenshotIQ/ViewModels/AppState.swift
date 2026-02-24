import Foundation
import SwiftUI
import Combine
import UIKit
import CryptoKit

@MainActor
final class AppState: ObservableObject {
    static let defaultPromptTemplate = "请输出：1) 情绪判断，2) 核心诉求，3) 风险点，4) 三种高情商回复版本（温和/坚定/幽默），5) 推荐发送版本与理由。每条回复必须简短、可直接复制。"
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

    @Published var latestInsightQuestion: String = ""
    @Published var latestInsightAnswer: String = ""
    @Published var latestAnalysis: ConversationAnalysis?
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

    let api = APIClient()
    private let lastClipboardHashKey = "last_clipboard_screenshot_hash"
    private let defaultPromptKey = "default_auto_prompt"
    private let autoReplyEnabledKey = "default_auto_reply_enabled"

    init() {
        self.apiBaseURL = APIClient.currentBaseURLString()
        self.autoReplyEnabled = UserDefaults.standard.object(forKey: autoReplyEnabledKey) as? Bool ?? true
        self.defaultAutoPrompt = UserDefaults.standard.string(forKey: defaultPromptKey)
            ?? AppState.defaultPromptTemplate
    }

    func resetDefaultPrompt() {
        defaultAutoPrompt = AppState.defaultPromptTemplate
    }

    func resetAPIBaseURL() {
        apiBaseURL = AppState.defaultAPIBaseURL
        APIClient.saveBaseURL(apiBaseURL)
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

    func ask(_ question: String, source: String = "manual") async {
        guard let sessionID else {
            setStage(.failed, status: "会话不可用", error: "session_id 缺失")
            return
        }

        if source == "auto-import" {
            setStage(.generating, status: "正在生成高情商回复建议...")
            pushTimeline("开始调用大模型生成建议")
        }

        do {
            let resp = try await api.sendMessage(sessionID: sessionID, message: question, imageIDs: selectedImageIDs, mode: "hq_reply")
            messages.append("Q: \(question)")
            messages.append("A: \(resp.answer)")

            citations = resp.citations
            followups = resp.followups
            latestInsightQuestion = question
            latestInsightAnswer = resp.answer
            latestAnalysis = resp.analysis
            latestReplyOptions = resp.replyOptions
            latestBestReply = resp.bestReply?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            latestWhy = resp.why?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            updateModelInfo(model: resp.model, llmError: resp.llmError)
            await refreshEvidenceItems(sessionID: sessionID, citations: resp.citations)

            if source == "auto-import" {
                if !resp.analysisSteps.isEmpty {
                    resp.analysisSteps.forEach { pushTimeline($0) }
                }
                pushTimeline("已生成高情商回复建议")
                setStage(.ready, status: "已生成高情商回复建议（已在当前页展示）")
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

        await ask(prompt, source: "auto-import")
        if importStage == .ready {
            pushTimeline("流程结束")
        }
    }

    func importFromClipboardIfAvailable() async {
        guard let image = UIPasteboard.general.image else { return }
        guard let data = image.jpegData(compressionQuality: 0.9) else { return }
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let last = UserDefaults.standard.string(forKey: lastClipboardHashKey)
        guard hash != last else { return }
        UserDefaults.standard.set(hash, forKey: lastClipboardHashKey)
        await importScreenshots([image], source: "clipboard")
    }
}
