import Foundation
import UIKit

struct SessionRef: Codable, Identifiable {
    let id: String
    let createdAt: Date
}

struct ImageRef: Codable, Identifiable, Hashable {
    let id: String
    let uploadURL: URL
}

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

enum ImportStage: String, Codable {
    case idle
    case importing
    case analyzing
    case generating
    case ready
    case failed
}

struct ConversationAnalysis: Codable, Hashable {
    let emotion: String
    let coreNeed: String
    let riskPoint: String
}

struct SpeakerSplit: Codable, Hashable {
    let otherLines: [String]
    let selfLines: [String]
    let mappingRule: String
    let confidence: Double
    let lowConfidenceReason: String?
}

struct ConversationIntent: Codable, Hashable {
    let otherIntent: String
    let selfIntent: String
}

struct ReplyOption: Codable, Hashable, Identifiable {
    var id: String { style + ":" + text }
    let style: String
    let text: String
}

struct ChatResponse: Codable {
    let answer: String
    let citations: [Citation]
    let followups: [String]
    let confidence: Double
    let isSpeculative: Bool
    let analysisSteps: [String]
    let analysis: ConversationAnalysis?
    let replyOptions: [ReplyOption]
    let bestReply: String?
    let why: String?
    let model: String?
    let llmError: String?
    let speakerSplit: SpeakerSplit?
    let intent: ConversationIntent?
}

struct Evidence: Codable, Identifiable {
    var id: String { factId + ":" + imageId }
    let imageId: String
    let bbox: BoundingBox
    let excerpt: String
    let factId: String
    let confidence: Double
}

struct ImportedScreenshot: Identifiable {
    let id: String
    let imageID: String
    let image: UIImage
    let source: String
}
