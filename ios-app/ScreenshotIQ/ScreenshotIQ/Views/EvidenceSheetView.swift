import SwiftUI

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
