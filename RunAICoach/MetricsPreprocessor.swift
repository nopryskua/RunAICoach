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

struct Aggregates: Encodable {
    let power30sWindowAverage: Double
    let sessionPowerAverage: Double
    let pace30sWindowAverage: Double
    let pace60sWindowAverage: Double
    let sessionPaceAverage: Double
}

class MetricsPreprocessor {
    private var lastPoint: MetricPoint?
    private let logger = Logger(subsystem: "com.runaicoach", category: "MetricsPreprocessor")

    // Power aggregations
    private var power30sWindow: RollingWindow
    private var powerSessionTotal: SessionTotal

    // speed aggregations
    private var speed30sWindow: RollingWindow
    private var speed60sWindow: RollingWindow
    private var speedSessionTotal: SessionTotal

    init() {
        power30sWindow = RollingWindow(interval: 30) // 30 second window
        powerSessionTotal = SessionTotal()

        speed30sWindow = RollingWindow(interval: 30) // 30 second window
        speed60sWindow = RollingWindow(interval: 60) // 60 second window
        speedSessionTotal = SessionTotal()
    }

    private func speedToPace(_ speed: Double) -> Double { // pace in minutes per km (using speed in m/s)
        guard speed > 0 else { return 0.0 }
        return 1000 / speed / 60
    }

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

        lastPoint = point

        // Update power aggregations
        power30sWindow.add(value: point.runningPower, at: point.timestamp)
        powerSessionTotal.add(point.runningPower)

        // Update speed aggregations
        speed30sWindow.add(value: point.runningSpeed, at: point.timestamp)
        speed60sWindow.add(value: point.runningSpeed, at: point.timestamp)
        speedSessionTotal.add(point.runningSpeed)

        logger.debug("Added new metric point")
    }

    func getAggregates() -> Aggregates {
        return Aggregates(
            power30sWindowAverage: power30sWindow.average(),
            sessionPowerAverage: powerSessionTotal.average(),
            pace30sWindowAverage: speedToPace(speed30sWindow.average()),
            pace60sWindowAverage: speedToPace(speed60sWindow.average()),
            sessionPaceAverage: speedToPace(speedSessionTotal.average())
        )
    }

    func getLatestMetrics() -> MetricPoint? {
        return lastPoint
    }

    func clear() {
        lastPoint = nil
        power30sWindow = RollingWindow(interval: 30)
        powerSessionTotal = SessionTotal()
        speed30sWindow = RollingWindow(interval: 30)
        speed60sWindow = RollingWindow(interval: 60)
        speedSessionTotal = SessionTotal()
    }
}
