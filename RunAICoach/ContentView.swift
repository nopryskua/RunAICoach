import SwiftUI

struct ContentView: View {
    @StateObject private var sessionManager = PhoneSessionManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("RunAI Coach")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                if sessionManager.isWorkoutActive {
                    VStack(spacing: 15) {
                        if let latest = sessionManager.getLatestMetrics() {
                            Group {
                                MetricRow(
                                    title: "Heart Rate",
                                    value: String(format: "%.0f", latest.heartRate),
                                    unit: "BPM"
                                )
                                MetricRow(
                                    title: "Distance",
                                    value: String(format: "%.2f", latest.distance / 1000),
                                    unit: "km"
                                )
                                MetricRow(
                                    title: "Step Count",
                                    value: String(format: "%.0f", latest.stepCount),
                                    unit: "count"
                                )
                                MetricRow(
                                    title: "Energy",
                                    value: String(format: "%.0f", latest.activeEnergy),
                                    unit: "kcal",
                                    style: nil
                                )
                                MetricRow(
                                    title: "Elevation",
                                    value: String(format: "%.1f", latest.elevation),
                                    unit: "m"
                                )
                                MetricRow(
                                    title: "Running Power",
                                    value: String(format: "%.0f", latest.runningPower),
                                    unit: "W"
                                )
                                MetricRow(
                                    title: "Running Speed",
                                    value: String(format: "%.1f", latest.runningSpeed),
                                    unit: "m/s"
                                )
                            }

                            Divider()

                            Group {
                                MetricRow(title: "Started", value: latest.startedAt, unit: "", style: .time)
                                MetricRow(title: "Last Update", value: latest.timestamp, unit: "", style: .time)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(15)
                    .shadow(radius: 5)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "applewatch")
                            .font(.system(size: 50))
                        Text("Start your workout on Apple Watch")
                            .font(.headline)
                        Text("Metrics will appear here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
    }
}

struct MetricRow: View {
    let title: String
    let value: Any
    let unit: String
    var style: Text.DateStyle?

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
            if let date = value as? Date, let style = style {
                Text(date, style: style)
                    .font(.title2)
                    .fontWeight(.semibold)
            } else if let stringValue = value as? String {
                Text(stringValue)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            if !unit.isEmpty {
                Text(unit)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}
