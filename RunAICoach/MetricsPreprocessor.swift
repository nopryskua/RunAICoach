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
    let sessionDuration: TimeInterval
    let powerWatts30sWindowAverage: Double
    let sessionPowerWattsAverage: Double
    let paceMinutesPerKm30sWindowAverage: Double
    let paceMinutesPerKm60sWindowAverage: Double
    let paceMinutesPerKm60sWindowRateOfChange: Double
    let sessionPaceMinutesPerKmAverage: Double
    let heartRateBPM30sWindowAverage: Double
    let heartRateBPM60sWindowAverage: Double
    let heartRateBPM60sWindowRateOfChange: Double
    let sessionHeartRateBPMAverage: Double
    let sessionHeartRateBPMMin: Double
    let sessionHeartRateBPMMax: Double
    let cadenceSPM30sWindow: Double
    let cadenceSPM60sWindow: Double
    let distanceMeters: Double
    let strideLengthMPS: Double
    let sessionElevationGainMeters: Double
    let elevationGainMeters30sWindow: Double
    let gradePercentage10sWindow: Double
    let gradeAdjustedPace60sWindow: Double
}

// MARK: - Utility Functions

private func sessionDuration(timestamp: Date, startedAt: Date) -> TimeInterval {
    return timestamp.timeIntervalSince(startedAt)
}

private func speedToPaceMinutesPerKm(_ speed: Double) -> Double { // Pace in minutes per km using speed in m/s
    guard speed > 0 else { return 0.0 }
    return 1000 / speed / 60
}

private func cadenceSPM(stepCount: Double, duration: TimeInterval) -> Double {
    guard duration > 0 else { return 0.0 }
    return stepCount * 60 / duration
}

private func strideLengthMPS(distance: Double, stepCount: Double) -> Double {
    guard stepCount > 0 else { return 0.0 }
    return distance / stepCount
}

private func calculateGradePercentage(elevationChange: Double, horizontalDistance: Double) -> Double {
    guard horizontalDistance > 0 else { return 0.0 }
    return (elevationChange / horizontalDistance) * 100.0
}

private func calculateGradeAdjustmentFactor(grade: Double) -> Double {
    // Strava's empirically derived adjustment factors
    // For uphill (positive grade)
    if grade > 0 {
        return 1.0 + (0.03 * grade) + (0.0005 * grade * grade)
    }
    // For downhill (negative grade)
    else if grade < 0 {
        return 1.0 + (0.02 * grade) + (0.0003 * grade * grade)
    }
    // Flat terrain
    return 1.0
}

private func calculateGAP(pace: Double, grade: Double) -> Double {
    let adjustmentFactor = calculateGradeAdjustmentFactor(grade: grade)
    return pace * adjustmentFactor
}

private func calculateRateOfChange(current: Double, previous: Double) -> Double {
    guard previous > 0 else { return 0.0 }
    return current - previous
}

// MARK: - MetricsPreprocessor

class MetricsPreprocessor {
    private var lastPoint: MetricPoint?
    private let logger = Logger(subsystem: "com.runaicoach", category: "MetricsPreprocessor")

    // Power aggregations
    private var power30sWindow: RollingWindow
    private var powerSessionTotal: SessionTotal

    // Pace aggregations (replacing speed windows)
    private var pace30sWindow: RollingWindow
    private var pace60sPreviousWindow: RollingWindow
    private var pace60sWindow: RollingWindow
    private var paceSessionTotal: SessionTotal

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

    // Distance aggregations
    private var distance60sDeltaTracker: DeltaTracker
    private var distance60sWindow: RollingWindow

    // Elevation aggregations
    private var elevationGain3sDeltaTracker: DeltaTracker
    private var elevationGain3sPreviousWindow: RollingWindow
    private var elevationGain3sWindow: RollingWindow
    private var elevationGainSessionTotal: Double
    private var elevationGainSessionTotal30sDeltaTracker: DeltaTracker
    private var elevationGainSessionTotal30sWindow: RollingWindow
    private var elevationGain10sDeltaTracker: DeltaTracker
    private var elevationGain10sWindow: RollingWindow
    private var distance10sDeltaTracker: DeltaTracker
    private var distance10sWindow: RollingWindow
    private var gap60sWindow: RollingWindow

    init() {
        power30sWindow = RollingWindow(interval: 30)
        powerSessionTotal = SessionTotal()

        // Initialize pace windows with speedToPaceMinutesPerKm transform
        pace30sWindow = RollingWindow(interval: 30, transform: speedToPaceMinutesPerKm)
        pace60sPreviousWindow = RollingWindow(interval: 60, transform: speedToPaceMinutesPerKm)
        pace60sWindow = RollingWindow(interval: 60, previous: pace60sPreviousWindow, transform: speedToPaceMinutesPerKm)
        paceSessionTotal = SessionTotal(transform: speedToPaceMinutesPerKm)

        heartRate30sWindow = RollingWindow(interval: 30)
        heartRate60sPreviousWindow = RollingWindow(interval: 60)
        heartRate60sWindow = RollingWindow(interval: 60, previous: heartRate60sPreviousWindow)
        heartRateSessionTotal = SessionTotal()

        stepCount30sDeltaTracker = DeltaTracker()
        stepCount30sWindow = RollingWindow(interval: 30, transform: stepCount30sDeltaTracker.delta)
        stepCount60sDeltaTracker = DeltaTracker()
        stepCount60sWindow = RollingWindow(interval: 60, transform: stepCount60sDeltaTracker.delta)

        distance60sDeltaTracker = DeltaTracker()
        distance60sWindow = RollingWindow(interval: 60, transform: distance60sDeltaTracker.delta)

        elevationGain3sDeltaTracker = DeltaTracker()
        elevationGain3sPreviousWindow = RollingWindow(interval: 3)
        elevationGain3sWindow = RollingWindow(interval: 3, previous: elevationGain3sPreviousWindow, transform: elevationGain3sDeltaTracker.delta)
        elevationGainSessionTotal = 0.0
        elevationGainSessionTotal30sDeltaTracker = DeltaTracker()
        elevationGainSessionTotal30sWindow = RollingWindow(interval: 30, transform: elevationGainSessionTotal30sDeltaTracker.delta)
        elevationGain10sDeltaTracker = DeltaTracker()
        elevationGain10sWindow = RollingWindow(interval: 10, transform: elevationGain10sDeltaTracker.delta)
        distance10sDeltaTracker = DeltaTracker()
        distance10sWindow = RollingWindow(interval: 10, transform: distance10sDeltaTracker.delta)
        gap60sWindow = RollingWindow(interval: 60)
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

        // Update pace aggregations (using runningSpeed which will be transformed to pace)
        pace30sWindow.add(value: point.runningSpeed, at: point.timestamp)
        pace60sWindow.add(value: point.runningSpeed, at: point.timestamp)
        paceSessionTotal.add(point.runningSpeed)

        // Update heart rate aggregations
        heartRate30sWindow.add(value: point.heartRate, at: point.timestamp)
        heartRate60sWindow.add(value: point.heartRate, at: point.timestamp)
        heartRateSessionTotal.add(point.heartRate)

        // Update step count aggregations
        stepCount30sWindow.add(value: point.stepCount, at: point.timestamp)
        stepCount60sWindow.add(value: point.stepCount, at: point.timestamp)

        // Update distance aggregations
        distance60sWindow.add(value: point.distance, at: point.timestamp)

        // Update elevation gain aggregations
        elevationGain3sWindow.add(value: point.elevation, at: point.timestamp)
        elevationGainSessionTotal += max(0.0, elevationGain3sWindow.average() - elevationGain3sPreviousWindow.average())
        elevationGainSessionTotal30sWindow.add(value: elevationGainSessionTotal, at: point.timestamp)
        elevationGain10sWindow.add(value: point.elevation, at: point.timestamp)
        distance10sWindow.add(value: point.distance, at: point.timestamp)
        let currentPace = speedToPaceMinutesPerKm(point.runningSpeed)
        let currentGrade = calculateGradePercentage(
            elevationChange: elevationGain10sWindow.sum(),
            horizontalDistance: distance10sWindow.sum()
        )
        let gap = calculateGAP(pace: currentPace, grade: currentGrade)
        gap60sWindow.add(value: gap, at: point.timestamp)

        logger.debug("Added new metric point")
    }

    func getAggregates() -> Aggregates {
        return Aggregates(
            sessionDuration: sessionDuration(timestamp: lastPoint?.timestamp ?? Date.distantPast,
                                             startedAt: lastPoint?.startedAt ?? Date.distantPast),
            powerWatts30sWindowAverage: power30sWindow.average(),
            sessionPowerWattsAverage: powerSessionTotal.average(),
            paceMinutesPerKm30sWindowAverage: pace30sWindow.average(),
            paceMinutesPerKm60sWindowAverage: pace60sWindow.average(),
            paceMinutesPerKm60sWindowRateOfChange: calculateRateOfChange(
                current: pace60sWindow.average(),
                previous: pace60sPreviousWindow.average()
            ),
            sessionPaceMinutesPerKmAverage: paceSessionTotal.average(),
            heartRateBPM30sWindowAverage: heartRate30sWindow.average(),
            heartRateBPM60sWindowAverage: heartRate60sWindow.average(),
            heartRateBPM60sWindowRateOfChange: calculateRateOfChange(
                current: heartRate60sWindow.average(),
                previous: heartRate60sPreviousWindow.average()
            ),
            sessionHeartRateBPMAverage: heartRateSessionTotal.average(),
            sessionHeartRateBPMMin: heartRateSessionTotal.getMin(),
            sessionHeartRateBPMMax: heartRateSessionTotal.getMax(),
            cadenceSPM30sWindow: cadenceSPM(stepCount: stepCount30sWindow.sum(), duration: stepCount30sWindow.duration()),
            cadenceSPM60sWindow: cadenceSPM(stepCount: stepCount60sWindow.sum(), duration: stepCount60sWindow.duration()),
            distanceMeters: lastPoint?.distance ?? 0,
            strideLengthMPS: strideLengthMPS(distance: distance60sWindow.sum(), stepCount: stepCount60sWindow.sum()),
            sessionElevationGainMeters: elevationGainSessionTotal,
            elevationGainMeters30sWindow: elevationGainSessionTotal30sWindow.sum(),
            gradePercentage10sWindow: calculateGradePercentage(
                elevationChange: elevationGain10sWindow.sum(),
                horizontalDistance: distance10sWindow.sum()
            ),
            gradeAdjustedPace60sWindow: gap60sWindow.average()
        )
    }

    func getLatestMetrics() -> MetricPoint? {
        return lastPoint
    }

    func clear() {
        lastPoint = nil

        power30sWindow = RollingWindow(interval: 30)
        powerSessionTotal = SessionTotal()

        pace30sWindow = RollingWindow(interval: 30, transform: speedToPaceMinutesPerKm)
        pace60sPreviousWindow = RollingWindow(interval: 60, transform: speedToPaceMinutesPerKm)
        pace60sWindow = RollingWindow(interval: 60, previous: pace60sPreviousWindow, transform: speedToPaceMinutesPerKm)
        paceSessionTotal = SessionTotal(transform: speedToPaceMinutesPerKm)

        heartRate30sWindow = RollingWindow(interval: 30)
        heartRate60sPreviousWindow = RollingWindow(interval: 60)
        heartRate60sWindow = RollingWindow(interval: 60, previous: heartRate60sPreviousWindow)
        heartRateSessionTotal = SessionTotal()

        stepCount30sDeltaTracker = DeltaTracker()
        stepCount30sWindow = RollingWindow(interval: 30, transform: stepCount30sDeltaTracker.delta)
        stepCount60sDeltaTracker = DeltaTracker()
        stepCount60sWindow = RollingWindow(interval: 60, transform: stepCount60sDeltaTracker.delta)

        distance60sDeltaTracker = DeltaTracker()
        distance60sWindow = RollingWindow(interval: 60, transform: distance60sDeltaTracker.delta)

        elevationGain3sDeltaTracker = DeltaTracker()
        elevationGain3sWindow = RollingWindow(interval: 3, previous: elevationGain3sPreviousWindow, transform: elevationGain3sDeltaTracker.delta)
        elevationGainSessionTotal = 0.0
        elevationGainSessionTotal30sDeltaTracker = DeltaTracker()
        elevationGainSessionTotal30sWindow = RollingWindow(interval: 30, transform: elevationGainSessionTotal30sDeltaTracker.delta)
        elevationGain10sDeltaTracker = DeltaTracker()
        elevationGain10sWindow = RollingWindow(interval: 10, transform: elevationGain10sDeltaTracker.delta)
        distance10sDeltaTracker = DeltaTracker()
        distance10sWindow = RollingWindow(interval: 10, transform: distance10sDeltaTracker.delta)
        gap60sWindow = RollingWindow(interval: 60)
    }
}
