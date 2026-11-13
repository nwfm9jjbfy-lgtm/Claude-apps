import SwiftUI

@main
struct ClaudeWatchApp: App {
    @State private var settings = AppSettings()
    @State private var store = ConversationStore()
    @State private var speech = SpeechService()

    var body: some Scene {
        WindowGroup {
            Group {
                if settings.hasAPIKey {
                    ConversationListView()
                } else {
                    OnboardingView()
                }
            }
            .environment(settings)
            .environment(store)
            .environment(speech)
            .tint(.claudeOrange)
        }
    }
}

extension Color {
    static let claudeOrange = Color(red: 0.85, green: 0.47, blue: 0.34)
}
