import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            Form {
                Section("Privacy") {
                    Text("默认开启云端处理，用于截图理解与聊天推理。")
                }
                Section("Model") {
                    Text("默认自动路由：简单问题低成本模型，复杂问题高能力模型。")
                }
                Section("API") {
                    TextField("API Base URL", text: $appState.apiBaseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Button("恢复默认 API 地址") {
                        appState.resetAPIBaseURL()
                    }
                    Text("模拟器用 http://127.0.0.1:8080；真机请改成你的电脑IP，例如 http://192.168.1.23:8080。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("自动回复设置") {
                    Toggle("导入后自动生成建议", isOn: $appState.autoReplyEnabled)
                    Text("默认 Prompt")
                        .font(.subheadline.weight(.semibold))
                    TextEditor(text: $appState.defaultAutoPrompt)
                        .frame(minHeight: 140)
                    Button("恢复默认 Prompt") {
                        appState.resetDefaultPrompt()
                    }
                    Text("导入截图后会自动用这个 Prompt 调用 Chat，生成高情商回复建议。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
