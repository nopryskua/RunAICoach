//
//  ContentView.swift
//  RunAICoachWatch Watch App
//
//  Created by Nestor Oprysk on 5/3/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject var hk = HealthKitManager()
    @State private var inWorkout = false
    var body: some View {
        VStack {
            Text("HR: \(Int(hk.heartRate)) bpm")
            Text(String(format: "Dist: %.2f m", hk.distance))
            Button(inWorkout ? "Stop" : "Start") {
                if inWorkout { hk.stopWorkout() } else { hk.startWorkout() }
                inWorkout.toggle()
            }
        }
        .padding()
    }
}
