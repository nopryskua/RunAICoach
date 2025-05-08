import Foundation
import os.log

struct MetricPoint {
    let heartRate: Double
    let distance: Double
    let stepCount: Double
    let activeEnergy: Double
    let elevation: Double
    let runningPower: Double
    let runningSpeed: Double
    let timestamp: Date
    let startedAt: Date
}

class MetricsPreprocessor {
    private var timeSeries: [MetricPoint] = []
    private let logger = Logger(subsystem: "com.runaicoach", category: "MetricsPreprocessor")

    func addMetrics(_ data: [String: Any], _ lastElevation: Double?) {
        let point = MetricPoint(
            heartRate: data["heartRate"] as? Double ?? 0,
            distance: data["distance"] as? Double ?? 0,
            stepCount: data["stepCount"] as? Double ?? 0,
            activeEnergy: data["activeEnergy"] as? Double ?? 0,
            elevation: lastElevation ?? 0,
            runningPower: data["runningPower"] as? Double ?? 0,
            runningSpeed: data["runningSpeed"] as? Double ?? 0,
            timestamp: Date(timeIntervalSince1970: data["timestamp"] as? TimeInterval ?? 0),
            startedAt: Date(timeIntervalSince1970: data["startedAt"] as? TimeInterval ?? 0)
        )

        timeSeries.append(point)
        logger.debug("Added new metric point, total points: \(timeSeries.count)")
    }

    func getPreprocessedMetrics() -> [MetricPoint] {
        // TODO: Implement actual preprocessing logic
        return timeSeries
    }

    func getLatestMetrics() -> MetricPoint? {
        return timeSeries.last
    }

    func clear() {
        timeSeries.removeAll()
    }
}
