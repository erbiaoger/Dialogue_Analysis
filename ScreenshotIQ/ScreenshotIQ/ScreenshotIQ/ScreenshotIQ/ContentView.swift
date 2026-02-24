import SwiftUI
import UIKit

struct BoundingBox: Codable, Hashable {
    let x: Double
    let y: Double
    let w: Double
    let h: Double
}

struct Citation: Codable, Identifiable, Hashable {
    let id: String
    let evidenceId: String
    let factId: String
    let reasoningRole: String
    let score: Double
}

struct ChatResponseModel: Codable {
    let answer: String
    let citations: [Citation]
    let followups: [String]
    let confidence: Double
    let isSpeculative: Bool
}

struct Evidence: Codable, Identifiable {
    var id: String { factId + ":" + imageId }
    let imageId: String
    let bbox: BoundingBox
    let excerpt: String
    let factId: String
    let confidence: Double
}

final class APIClient {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = URL(string: "http://127.0.0.1:8080")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func createSession(deviceID: String) async throws -> String {
        struct RequestBody: Codable { let device_id: String }
        struct ResponseBody: Codable { let session_id: String }

        let url = baseURL.appendingPathComponent("v1/sessions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(RequestBody(device_id: deviceID))

        let (data, _) = try await session.data(for: request)
        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        return decoded.session_id
    }

    func sendMessage(sessionID: String, message: String, imageIDs: [String]) async throws -> ChatResponseModel {
        struct Context: Codable { let image_ids: [String] }
        struct RequestBody: Codable { let message: String; let context: Context }
        struct ResponseBody: Codable {
            let answer: String
            let citations: [Citation]
            let followups: [String]
            let confidence: Double
            let is_speculative: Bool
        }

        let url = baseURL.appendingPathComponent("v1/sessions/\(sessionID)/chat")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(RequestBody(message: message, context: Context(image_ids: imageIDs)))

        let (data, _) = try await session.data(for: request)
        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        return ChatResponseModel(
            answer: decoded.answer,
            citations: decoded.citations,
            followups: decoded.followups,
            confidence: decoded.confidence,
            isSpeculative: decoded.is_speculative
        )
    }

    func fetchEvidence(sessionID: String, evidenceID: String) async throws -> Evidence {
        struct ResponseBody: Codable {
            let image_id: String
            let bbox: BoundingBox
            let excerpt: String
            let fact_id: String
            let confidence: Double
        }

        let url = baseURL.appendingPathComponent("v1/sessions/\(sessionID)/evidences/\(evidenceID)")
        let (data, _) = try await session.data(from: url)
        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        return Evidence(
            imageId: decoded.image_id,
            bbox: decoded.bbox,
            excerpt: decoded.excerpt,
            factId: decoded.fact_id,
            confidence: decoded.confidence
        )
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var sessionID: String?
    @Published var selectedImageIDs: [String] = []
    @Published var messages: [String] = []
    @Published var citations: [Citation] = []
    @Published var followups: [String] = []
    @Published var lastError: String?

    let api = APIClient()

    func bootstrapSessionIfNeeded() async {
        guard sessionID == nil else { return }
        do {
            let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            sessionID = try await api.createSession(deviceID: deviceID)
        } catch {
            lastError = "创建会话失败: \(error.localizedDescription)"
        }
    }

    func ask(_ question: String) async {
        guard let sessionID else {
            lastError = "会话未初始化"
            return
        }

        do {
            let resp = try await api.sendMessage(sessionID: sessionID, message: question, imageIDs: selectedImageIDs)
            messages.append("Q: \(question)")
            messages.append("A: \(resp.answer)")
            citations = resp.citations
            followups = resp.followups
            lastError = nil
        } catch {
            messages.append("A: 请求失败 \(error.localizedDescription)")
            lastError = "聊天请求失败: \(error.localizedDescription)"
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            SessionListView()
                .tabItem { Label("Home", systemImage: "house") }

            ImportView()
                .tabItem { Label("Import", systemImage: "photo.on.rectangle") }

            AnalysisView()
                .tabItem { Label("Analysis", systemImage: "sparkles.rectangle.stack") }

            ChatView()
                .tabItem { Label("Chat", systemImage: "message") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}

struct SessionListView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("ScreenshotIQ")
                    .font(.largeTitle.bold())
                Text("导入截图后，进行证据驱动问答")
                    .foregroundStyle(.secondary)

                if let id = appState.sessionID {
                    Text("Session: \(id)")
                        .font(.caption)
                        .textSelection(.enabled)
                } else {
                    Text("正在创建会话...")
                }

                if let error = appState.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Recent Sessions")
            .task {
                await appState.bootstrapSessionIfNeeded()
            }
        }
    }
}

struct ImportView: View {
    @EnvironmentObject private var appState: AppState
    @State private var imageIDInput = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Mock Import") {
                    TextField("粘贴 image_id（后端 presign 后）", text: $imageIDInput)
                    Button("加入当前上下文") {
                        let trimmed = imageIDInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        appState.selectedImageIDs.append(trimmed)
                        imageIDInput = ""
                    }
                }

                Section("已选择图片") {
                    if appState.selectedImageIDs.isEmpty {
                        Text("暂无")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(appState.selectedImageIDs, id: \.self) { id in
                            Text(id)
                                .font(.caption)
                                .textSelection(.enabled)
                        }
                        .onDelete { indexSet in
                            appState.selectedImageIDs.remove(atOffsets: indexSet)
                        }
                    }
                }
            }
            .navigationTitle("Import")
        }
    }
}

struct AnalysisView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 10) {
                Text("Analysis Summary")
                    .font(.title2.bold())
                Text("当前版本可联调后端分析与聊天接口。")
                    .foregroundStyle(.secondary)
                Text("已选图片数：\(appState.selectedImageIDs.count)")
                Text("下一步：接入系统相册多选 + 上传。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle("Analysis")
        }
    }
}

struct ChatView: View {
    @EnvironmentObject private var appState: AppState
    @State private var question = ""
    @State private var selectedEvidence: Evidence?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(appState.messages, id: \.self) { line in
                            Text(line)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                        }

                        if !appState.citations.isEmpty {
                            Text("证据引用")
                                .font(.headline)
                            ForEach(appState.citations) { c in
                                Button("\(c.reasoningRole) / score \(String(format: "%.2f", c.score))") {
                                    Task {
                                        guard let sessionID = appState.sessionID else { return }
                                        selectedEvidence = try? await appState.api.fetchEvidence(sessionID: sessionID, evidenceID: c.evidenceId)
                                    }
                                }
                            }
                        }

                        if !appState.followups.isEmpty {
                            Text("建议追问")
                                .font(.headline)
                            ForEach(appState.followups, id: \.self) { f in
                                Text("- \(f)")
                            }
                        }
                    }
                    .padding()
                }

                HStack {
                    TextField("输入问题", text: $question)
                        .textFieldStyle(.roundedBorder)
                    Button("发送") {
                        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !q.isEmpty else { return }
                        question = ""
                        Task { await appState.ask(q) }
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("Chat")
            .sheet(item: $selectedEvidence) { evidence in
                EvidenceSheetView(evidence: evidence)
            }
        }
    }
}

struct EvidenceSheetView: View {
    let evidence: Evidence

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Evidence")
                .font(.title2.bold())
            Text("image_id: \(evidence.imageId)")
                .font(.caption)
                .textSelection(.enabled)
            Text("excerpt: \(evidence.excerpt)")
            Text("bbox: x=\(evidence.bbox.x), y=\(evidence.bbox.y), w=\(evidence.bbox.w), h=\(evidence.bbox.h)")
                .font(.caption)
            Text("confidence: \(String(format: "%.2f", evidence.confidence))")
                .font(.caption)
            Spacer()
        }
        .padding()
    }
}

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("Privacy") {
                    Text("默认开启云端处理，用于截图理解与聊天推理。")
                }
                Section("Model") {
                    Text("默认自动路由：简单问题低成本模型，复杂问题高能力模型。")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
