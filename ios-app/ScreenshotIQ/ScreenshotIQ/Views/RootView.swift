import SwiftUI

struct RootView: View {
    private enum Tab: Hashable {
        case importWorkbench
        case chat
        case settings
    }

    @State private var selectedTab: Tab = .importWorkbench

    var body: some View {
        TabView(selection: $selectedTab) {
            ImportView()
                .tag(Tab.importWorkbench)
                .tabItem { Label("Import", systemImage: "photo.on.rectangle") }
            ChatView()
                .tag(Tab.chat)
                .tabItem { Label("Chat", systemImage: "message") }
            SettingsView()
                .tag(Tab.settings)
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}
