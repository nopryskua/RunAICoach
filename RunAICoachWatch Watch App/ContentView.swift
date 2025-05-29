import SwiftUI

struct ContentView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @State private var inWorkout = false

    var body: some View {
        VStack(spacing: 8) {
            if inWorkout {
                Text("HR: \(Int(healthKitManager.heartRate)) bpm")
                    .font(.system(size: 20, weight: .semibold))
            } else {
                Text("Ready to run?")
                    .font(.system(size: 20, weight: .semibold))
            }

            Button(inWorkout ? "Stop" : "Start") {
                if inWorkout {
                    healthKitManager.stopWorkout()
                } else {
                    healthKitManager.startWorkout()
                }
                inWorkout.toggle()
            }
            .buttonStyle(.borderedProminent)
            .tint(inWorkout ? .red : .green)
        }
        .padding()
        .onChange(of: healthKitManager.isWorkoutActive) { _, newValue in
            inWorkout = newValue
        }
    }
}
