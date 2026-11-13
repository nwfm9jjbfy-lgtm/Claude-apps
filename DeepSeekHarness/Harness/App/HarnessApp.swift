import SwiftUI

@main
struct HarnessApp: App {
    @State private var settings = AppSettings()
    @State private var store = SessionStore()
    @State private var hub = AgentHub()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(store)
                .environment(hub)
        }
    }
}

extension Color {
    static let deepBlue = Color(red: 0.30, green: 0.42, blue: 1.0)
}
