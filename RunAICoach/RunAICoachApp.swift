//
//  RunAICoachApp.swift
//  RunAICoach
//
//  Created by Nestor Oprysk on 5/3/25.
//

import SwiftUI

@main
struct RunAICoachApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView().onAppear { _ = PhoneSessionManager.shared }
        }
    }
}
