import SwiftUI

@main
struct RunAICoachApp: App {
    @StateObject private var sessionManager = PhoneSessionManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionManager)
        }
    }
}
