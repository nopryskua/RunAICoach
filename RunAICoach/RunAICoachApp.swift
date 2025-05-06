//
//  RunAICoachApp.swift
//  RunAICoach
//
//  Created by Nestor Oprysk on 5/3/25.
//

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
