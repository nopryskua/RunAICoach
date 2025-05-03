//
//  ContentView.swift
//  RunAICoachWatch Watch App
//
//  Created by Nestor Oprysk on 5/3/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var hk = HealthKitManager()
    @State private var inWorkout = false
    
    var body: some View {
        VStack(spacing: 8) {
            if inWorkout {
                Text("HR: \(Int(hk.heartRate)) bpm")
                    .font(.system(size: 20, weight: .semibold))
                Text(String(format: "Dist: %.2f m", hk.distance))
                    .font(.system(size: 20, weight: .semibold))
            } else {
                Text("Ready to run?")
                    .font(.system(size: 20, weight: .semibold))
            }
            
            Button(inWorkout ? "Stop" : "Start") {
                if inWorkout {
                    hk.stopWorkout()
                } else {
                    hk.startWorkout()
                }
                inWorkout.toggle()
            }
            .buttonStyle(.borderedProminent)
            .tint(inWorkout ? .red : .green)
        }
        .padding()
        .onChange(of: hk.isWorkoutActive) { oldValue, newValue in
            inWorkout = newValue
        }
    }
}
