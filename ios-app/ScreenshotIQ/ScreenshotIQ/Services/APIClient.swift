import Foundation
import UIKit
import CryptoKit

final class APIClient {
    private let session: URLSession
    private static let baseURLKey = "api_base_url"
    static let defaultBaseURLString = "http://127.0.0.1:8080"

    private var baseURL: URL {
        let raw = UserDefaults.standard.string(forKey: Self.baseURLKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let raw, !raw.isEmpty, let url = URL(string: raw) {
            return url
        }
        return URL(string: Self.defaultBaseURLString)!
    }

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
            return
        }
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 120
        configuration.allowsConstrainedNetworkAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        self.session = URLSession(configuration: configuration)
    }

    private func shouldRetry(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }

    private func dataWithRetry(for request: URLRequest, retries: Int = 1) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            guard retries > 0, shouldRetry(error) else { throw error }
            try await Task.sleep(nanoseconds: 400_000_000)
            return try await dataWithRetry(for: request, retries: retries - 1)
        }
    }

    private func ensureHTTPSuccess(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            let snippet = body.isEmpty ? "empty response" : body
            throw NSError(
                domain: "APIClient",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(snippet)"]
            )
        }
    }

    static func currentBaseURLString() -> String {
        let raw = UserDefaults.standard.string(forKey: Self.baseURLKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let raw, !raw.isEmpty {
            return raw
        }
        return Self.defaultBaseURLString
    }

    static func saveBaseURL(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: Self.baseURLKey)
        } else {
            UserDefaults.standard.set(trimmed, forKey: Self.baseURLKey)
        }
    }

    func createSession(deviceID: String) async throws -> String {
        struct RequestBody: Codable { let device_id: String }
        struct ResponseBody: Codable { let session_id: String }

        let url = baseURL.appendingPathComponent("/v1/sessions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(RequestBody(device_id: deviceID))

        let (data, response) = try await dataWithRetry(for: request)
        try ensureHTTPSuccess(response, data: data)
        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        return decoded.session_id
    }

    func registerImage(sessionID: String, image: UIImage, filename: String) async throws -> String {
        struct PresignRequest: Codable {
            let filename: String
            let content_type: String
            let size: Int
        }
        struct PresignResponse: Codable {
            let image_id: String
            let upload_url: String
        }
        struct CommitMeta: Codable {
            let image_id: String
            let width: Int
            let height: Int
            let sha256: String
        }
        struct CommitPayload: Codable {
            let image_id: String
            let mime_type: String
            let image_base64: String
        }
        struct CommitRequest: Codable {
            let image_ids: [String]
            let meta: [CommitMeta]
            let payloads: [CommitPayload]
        }

        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw URLError(.cannotDecodeContentData)
        }

        let presignURL = baseURL.appendingPathComponent("/v1/sessions/\(sessionID)/images:presign")
        var presignReq = URLRequest(url: presignURL)
        presignReq.httpMethod = "POST"
        presignReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        presignReq.httpBody = try JSONEncoder().encode(PresignRequest(filename: filename, content_type: "image/jpeg", size: data.count))

        let (presignData, presignResp) = try await dataWithRetry(for: presignReq)
        try ensureHTTPSuccess(presignResp, data: presignData)
        let presign = try JSONDecoder().decode(PresignResponse.self, from: presignData)

        let width = Int(image.size.width * image.scale)
        let height = Int(image.size.height * image.scale)
        let digest = SHA256.hash(data: data)
        let sha256 = digest.map { String(format: "%02x", $0) }.joined()

        let commitURL = baseURL.appendingPathComponent("/v1/sessions/\(sessionID)/images:commit")
        var commitReq = URLRequest(url: commitURL)
        commitReq.httpMethod = "POST"
        commitReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let base64 = data.base64EncodedString()
        commitReq.httpBody = try JSONEncoder().encode(
            CommitRequest(
                image_ids: [presign.image_id],
                meta: [CommitMeta(image_id: presign.image_id, width: max(1, width), height: max(1, height), sha256: sha256)],
                payloads: [CommitPayload(image_id: presign.image_id, mime_type: "image/jpeg", image_base64: base64)]
            )
        )
        let (commitData, commitResp) = try await dataWithRetry(for: commitReq)
        try ensureHTTPSuccess(commitResp, data: commitData)
        return presign.image_id
    }

    func analyze(sessionID: String, imageIDs: [String]) async throws {
        struct AnalyzeRequest: Codable {
            let image_ids: [String]
        }
        let url = baseURL.appendingPathComponent("/v1/sessions/\(sessionID)/analysis")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(AnalyzeRequest(image_ids: imageIDs))
        let (data, response) = try await dataWithRetry(for: request)
        try ensureHTTPSuccess(response, data: data)
    }

    func sendMessage(sessionID: String, message: String, imageIDs: [String], mode: String = "hq_reply") async throws -> ChatResponse {
        struct Context: Codable { let image_ids: [String] }
        struct RequestBody: Codable { let message: String; let context: Context; let mode: String }
        struct AnalysisBody: Codable {
            let emotion: String?
            let core_need: String?
            let risk_point: String?
        }
        struct ReplyOptionBody: Codable {
            let style: String?
            let text: String?
        }
        struct ResponseBody: Codable {
            let answer: String
            let citations: [Citation]
            let followups: [String]
            let confidence: Double
            let is_speculative: Bool
            let analysis_steps: [String]?
            let analysis: AnalysisBody?
            let reply_options: [ReplyOptionBody]?
            let best_reply: String?
            let why: String?
            let model: String?
            let llm_error: String?
        }

        let url = baseURL.appendingPathComponent("/v1/sessions/\(sessionID)/chat")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(RequestBody(message: message, context: Context(image_ids: imageIDs), mode: mode))

        let (data, response) = try await dataWithRetry(for: request)
        try ensureHTTPSuccess(response, data: data)
        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        let mappedAnalysis: ConversationAnalysis? = {
            guard let analysis = decoded.analysis else { return nil }
            return ConversationAnalysis(
                emotion: analysis.emotion ?? "",
                coreNeed: analysis.core_need ?? "",
                riskPoint: analysis.risk_point ?? ""
            )
        }()
        let mappedReplyOptions = (decoded.reply_options ?? []).compactMap { option -> ReplyOption? in
            let style = (option.style ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let text = (option.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return ReplyOption(style: style.isEmpty ? "版本" : style, text: text)
        }
        return ChatResponse(
            answer: decoded.answer,
            citations: decoded.citations,
            followups: decoded.followups,
            confidence: decoded.confidence,
            isSpeculative: decoded.is_speculative,
            analysisSteps: decoded.analysis_steps ?? [],
            analysis: mappedAnalysis,
            replyOptions: mappedReplyOptions,
            bestReply: decoded.best_reply,
            why: decoded.why,
            model: decoded.model,
            llmError: decoded.llm_error
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

        let url = baseURL.appendingPathComponent("/v1/sessions/\(sessionID)/evidences/\(evidenceID)")
        let (data, response) = try await session.data(from: url)
        try ensureHTTPSuccess(response, data: data)
        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        return Evidence(imageId: decoded.image_id, bbox: decoded.bbox, excerpt: decoded.excerpt, factId: decoded.fact_id, confidence: decoded.confidence)
    }
}
