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
    let pace60sWindowRateOfChange: Double
    let sessionPaceAverage: Double
    let heartRate30sWindowAverage: Double
    let heartRate60sWindowAverage: Double
    let heartRate60sWindowRateOfChange: Double
    let sessionHeartRateAverage: Double
    let sessionHeartRateMin: Double
    let sessionHeartRateMax: Double
    let cadence30sWindow: Double
    let cadence60sWindow: Double
}

class MetricsPreprocessor {
    private var lastPoint: MetricPoint?
    private let logger = Logger(subsystem: "com.runaicoach", category: "MetricsPreprocessor")

    // Power aggregations
    private var power30sWindow: RollingWindow
    private var powerSessionTotal: SessionTotal

    // Speed aggregations
    private var speed30sWindow: RollingWindow
    private var speed60sPreviousWindow: RollingWindow
    private var speed60sWindow: RollingWindow
    private var speedSessionTotal: SessionTotal

    // Heart rate aggregations
    private var heartRate30sWindow: RollingWindow
    private var heartRate60sPreviousWindow: RollingWindow
    private var heartRate60sWindow: RollingWindow
    private var heartRateSessionTotal: SessionTotal

    // Step count aggregations
    private var stepCount30sDeltaTracker: DeltaTracker
    private var stepCount30sWindow: RollingWindow
    private var stepCount60sDeltaTracker: DeltaTracker
    private var stepCount60sWindow: RollingWindow

    init() {
        power30sWindow = RollingWindow(interval: 30)
        powerSessionTotal = SessionTotal()

        speed30sWindow = RollingWindow(interval: 30)
        speed60sPreviousWindow = RollingWindow(interval: 60)
        speed60sWindow = RollingWindow(interval: 60, previous: speed60sPreviousWindow)
        speedSessionTotal = SessionTotal()

        heartRate30sWindow = RollingWindow(interval: 30)
        heartRate60sPreviousWindow = RollingWindow(interval: 60)
        heartRate60sWindow = RollingWindow(interval: 60, previous: heartRate60sPreviousWindow)
        heartRateSessionTotal = SessionTotal()

        stepCount30sDeltaTracker = DeltaTracker()
        stepCount30sWindow = RollingWindow(interval: 30, transform: stepCount30sDeltaTracker.delta)
        stepCount60sDeltaTracker = DeltaTracker()
        stepCount60sWindow = RollingWindow(interval: 60, transform: stepCount60sDeltaTracker.delta)
    }

    private func speedToPace(_ speed: Double) -> Double { // Pace in minutes per km (using speed in m/s)
        guard speed > 0 else { return 0.0 }
        return 1000 / speed / 60
    }

    private func cadenceSPM(stepCount: Double, duration: TimeInterval) -> Double {
        guard duration > 0 else { return 0.0 }
        return stepCount * 60 / duration
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

        // Update heart rate aggregations
        heartRate30sWindow.add(value: point.heartRate, at: point.timestamp)
        heartRate60sWindow.add(value: point.heartRate, at: point.timestamp)
        heartRateSessionTotal.add(point.heartRate)

        // Update step count aggregations
        stepCount30sWindow.add(value: point.stepCount, at: point.timestamp)
        stepCount60sWindow.add(value: point.stepCount, at: point.timestamp)

        logger.debug("Added new metric point")
    }

    func getAggregates() -> Aggregates {
        return Aggregates(
            power30sWindowAverage: power30sWindow.average(),
            sessionPowerAverage: powerSessionTotal.average(),
            pace30sWindowAverage: speedToPace(speed30sWindow.average()),
            pace60sWindowAverage: speedToPace(speed60sWindow.average()),
            pace60sWindowRateOfChange: speedToPace(speed60sWindow.average()) - speedToPace(speed60sPreviousWindow.average()),
            sessionPaceAverage: speedToPace(speedSessionTotal.average()),
            heartRate30sWindowAverage: heartRate30sWindow.average(),
            heartRate60sWindowAverage: heartRate60sWindow.average(),
            heartRate60sWindowRateOfChange: heartRate60sWindow.average() - heartRate60sPreviousWindow.average(),
            sessionHeartRateAverage: heartRateSessionTotal.average(),
            sessionHeartRateMin: heartRateSessionTotal.getMin(),
            sessionHeartRateMax: heartRateSessionTotal.getMax(),
            cadence30sWindow: cadenceSPM(stepCount: stepCount30sWindow.sum(), duration: stepCount30sWindow.duration()),
            cadence60sWindow: cadenceSPM(stepCount: stepCount60sWindow.sum(), duration: stepCount60sWindow.duration())
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
        speed60sPreviousWindow = RollingWindow(interval: 60)
        speed60sWindow = RollingWindow(interval: 60, previous: speed60sPreviousWindow)
        speedSessionTotal = SessionTotal()

        heartRate30sWindow = RollingWindow(interval: 30)
        heartRate60sPreviousWindow = RollingWindow(interval: 60)
        heartRate60sWindow = RollingWindow(interval: 60, previous: heartRate60sPreviousWindow)
        heartRateSessionTotal = SessionTotal()

        stepCount30sDeltaTracker = DeltaTracker()
        stepCount30sWindow = RollingWindow(interval: 30, transform: stepCount30sDeltaTracker.delta)
        stepCount60sDeltaTracker = DeltaTracker()
        stepCount60sWindow = RollingWindow(interval: 60, transform: stepCount60sDeltaTracker.delta)
    }
}
