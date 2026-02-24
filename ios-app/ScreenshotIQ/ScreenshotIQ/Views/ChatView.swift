import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var appState: AppState
    @State private var question = ""
    @State private var selectedEvidence: Evidence?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(appState.lastModelInfo)
                            .font(.caption)
                            .foregroundStyle(.secondary)

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
