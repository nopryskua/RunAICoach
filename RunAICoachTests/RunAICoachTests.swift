//
//  RunAICoachTests.swift
//  RunAICoachTests
//
//  Created by Nestor Oprysk on 5/8/25.
//

@testable import RunAICoach
import XCTest

final class UnitTests: XCTestCase {
    // MARK: DeltaTracker Tests

    func testDeltaTracker() {
        let deltaTracker = DeltaTracker()
        XCTAssertEqual(deltaTracker.delta(2.0), 2.0)
        XCTAssertEqual(deltaTracker.delta(5.0), 3.0)
    }

    // MARK: - SessionTotal Tests

    func testEmptySessionTotal() {
        let total = SessionTotal()
        XCTAssertEqual(total.average(), 0.0)
        XCTAssertEqual(total.getMin(), 0.0)
        XCTAssertEqual(total.getMax(), 0.0)
    }

    func testBasicSessionTotal() {
        let total = SessionTotal()

        total.add(1.0)
        total.add(3.0)

        XCTAssertEqual(total.average(), 2.0)
        XCTAssertEqual(total.getMin(), 1.0)
        XCTAssertEqual(total.getMax(), 3.0)
    }

    func testSessionTotalWithTransform() {
        // Test with a transform that doubles the input
        let total = SessionTotal(transform: { $0 * 2 })

        total.add(1.0) // Will be stored as 2.0
        total.add(3.0) // Will be stored as 6.0

        XCTAssertEqual(total.average(), 4.0) // (2.0 + 6.0) / 2
        XCTAssertEqual(total.getMin(), 2.0) // min(2.0, 6.0)
        XCTAssertEqual(total.getMax(), 6.0) // max(2.0, 6.0)
    }

    // MARK: - RollingWindow Tests

    func testEmptyWindow() {
        let window = RollingWindow(interval: 10)
        XCTAssertEqual(window.average(), 0.0)
        XCTAssertEqual(window.sum(), 0.0)
        XCTAssertEqual(window.duration(), 0.0)
    }

    func testBasicAddition() {
        let window = RollingWindow(interval: 10)
        let now = Date()

        window.add(value: 10.0, at: now)
        window.add(value: 20.0, at: now.addingTimeInterval(2))
        window.add(value: 30.0, at: now.addingTimeInterval(4))

        XCTAssertEqual(window.sum(), 60.0)
        XCTAssertEqual(window.average(), 20.0)
        XCTAssertEqual(window.duration(), 4.0)
    }

    func testEvictionAfterInterval() {
        let window = RollingWindow(interval: 5)
        let now = Date()

        window.add(value: 10.0, at: now)
        window.add(value: 20.0, at: now.addingTimeInterval(2))
        window.add(value: 30.0, at: now.addingTimeInterval(6)) // Evicts 10.0

        XCTAssertEqual(window.sum(), 50.0)
        XCTAssertEqual(window.average(), 25.0)
        XCTAssertEqual(window.duration(), 4.0)
    }

    func testMultipleEvictions() {
        let window = RollingWindow(interval: 5)
        let now = Date()

        window.add(value: 5.0, at: now)
        window.add(value: 10.0, at: now.addingTimeInterval(1))
        window.add(value: 15.0, at: now.addingTimeInterval(2))
        window.add(value: 20.0, at: now.addingTimeInterval(8)) // Should evict first three

        XCTAssertEqual(window.average(), 20.0)
    }

    func testAllValuesEvicted() {
        let window = RollingWindow(interval: 3)
        let now = Date()

        window.add(value: 1.0, at: now)
        window.add(value: 2.0, at: now.addingTimeInterval(1))
        window.add(value: 3.0, at: now.addingTimeInterval(2))
        window.add(value: 4.0, at: now.addingTimeInterval(6)) // Evicts all previous

        XCTAssertEqual(window.average(), 4.0)
    }

    func testPrecisionHandling() {
        let window = RollingWindow(interval: 10)
        let now = Date()

        window.add(value: 0.1, at: now)
        window.add(value: 0.2, at: now.addingTimeInterval(1))
        window.add(value: 0.3, at: now.addingTimeInterval(2))

        XCTAssertEqual(window.average(), 0.2, accuracy: 0.0001)
    }

    func testPreviousWindow() {
        let previous = RollingWindow(interval: 10)
        let window = RollingWindow(interval: 10, previous: previous)
        let now = Date()

        window.add(value: 1.0, at: now)
        window.add(value: 3.0, at: now.addingTimeInterval(1))

        window.add(value: 2.0, at: now.addingTimeInterval(20))
        window.add(value: 4.0, at: now.addingTimeInterval(21))

        XCTAssertEqual(window.average(), 3.0)
        XCTAssertEqual(previous.average(), 2.0)
    }

    func testPreviousWindowEviction() {
        let previous = RollingWindow(interval: 10)
        let window = RollingWindow(interval: 10, previous: previous)
        let now = Date()

        window.add(value: 1.0, at: now)
        window.add(value: 3.0, at: now.addingTimeInterval(1))

        window.add(value: 2.0, at: now.addingTimeInterval(20))
        window.add(value: 4.0, at: now.addingTimeInterval(21))

        window.add(value: 4.0, at: now.addingTimeInterval(40))
        window.add(value: 6.0, at: now.addingTimeInterval(41))

        XCTAssertEqual(window.average(), 5.0)
        XCTAssertEqual(previous.average(), 3.0)
    }

    func testWindowWithTransform() {
        let deltaTracker = DeltaTracker()
        let window = RollingWindow(interval: 10, transform: deltaTracker.delta)
        let now = Date()

        window.add(value: 1.0, at: now)
        window.add(value: 2.0, at: now.addingTimeInterval(1))
        window.add(value: 3.0, at: now.addingTimeInterval(1)) // Mimics accumulated delta

        XCTAssertEqual(window.sum(), 3.0)
        XCTAssertEqual(window.average(), 1.0)
    }
}

final class MetricsPreprocessorTests: XCTestCase {
    var preprocessor: MetricsPreprocessor!
    let startedAt = Date()

    override func setUp() {
        super.setUp()
        preprocessor = MetricsPreprocessor()
    }

    override func tearDown() {
        preprocessor = nil
        super.tearDown()
    }

    // MARK: - Basic Initialization Tests

    func testInitialState() {
        let aggregates = preprocessor.getAggregates()

        // Test all metrics are zero/default
        XCTAssertEqual(aggregates.sessionDuration, 0)
        XCTAssertEqual(aggregates.powerWatts30sWindowAverage, 0)
        XCTAssertEqual(aggregates.sessionPowerWattsAverage, 0)
        XCTAssertEqual(aggregates.paceMinutesPerKm30sWindowAverage, 0)
        XCTAssertEqual(aggregates.paceMinutesPerKm60sWindowAverage, 0)
        XCTAssertEqual(aggregates.paceMinutesPerKm60sWindowRateOfChange, 0)
        XCTAssertEqual(aggregates.sessionPaceMinutesPerKmAverage, 0)
        XCTAssertEqual(aggregates.heartRateBPM30sWindowAverage, 0)
        XCTAssertEqual(aggregates.heartRateBPM60sWindowAverage, 0)
        XCTAssertEqual(aggregates.heartRateBPM60sWindowRateOfChange, 0)
        XCTAssertEqual(aggregates.sessionHeartRateBPMAverage, 0)
        XCTAssertEqual(aggregates.sessionHeartRateBPMMin, 0)
        XCTAssertEqual(aggregates.sessionHeartRateBPMMax, 0)
        XCTAssertEqual(aggregates.cadenceSPM30sWindow, 0)
        XCTAssertEqual(aggregates.cadenceSPM60sWindow, 0)
        XCTAssertEqual(aggregates.distanceMeters, 0)
        XCTAssertEqual(aggregates.strideLengthMPS, 0)
        XCTAssertEqual(aggregates.sessionElevationGainMeters, 0)
        XCTAssertEqual(aggregates.elevationGainMeters30sWindow, 0)
        XCTAssertEqual(aggregates.gradePercentage10sWindow, 0)
        XCTAssertEqual(aggregates.gradeAdjustedPace60sWindow, 0)
    }

    func testClear() {
        // Add some data
        let data: [String: Any] = [
            "heartRate": 150.0,
            "distance": 100.0,
            "stepCount": 50.0,
            "activeEnergy": 10.0,
            "runningPower": 200.0,
            "runningSpeed": 3.0,
            "timestamp": startedAt.timeIntervalSince1970,
            "startedAt": startedAt.timeIntervalSince1970,
        ]
        preprocessor.addMetrics(data, 0)

        // Clear and verify
        preprocessor.clear()
        let aggregates = preprocessor.getAggregates()
        XCTAssertEqual(aggregates.sessionDuration, 0)
        XCTAssertEqual(aggregates.powerWatts30sWindowAverage, 0)
        XCTAssertEqual(aggregates.sessionPowerWattsAverage, 0)
        XCTAssertEqual(aggregates.paceMinutesPerKm30sWindowAverage, 0)
        XCTAssertEqual(aggregates.paceMinutesPerKm60sWindowAverage, 0)
        XCTAssertEqual(aggregates.paceMinutesPerKm60sWindowRateOfChange, 0)
        XCTAssertEqual(aggregates.sessionPaceMinutesPerKmAverage, 0)
        XCTAssertEqual(aggregates.heartRateBPM30sWindowAverage, 0)
        XCTAssertEqual(aggregates.heartRateBPM60sWindowAverage, 0)
        XCTAssertEqual(aggregates.heartRateBPM60sWindowRateOfChange, 0)
        XCTAssertEqual(aggregates.sessionHeartRateBPMAverage, 0)
        XCTAssertEqual(aggregates.sessionHeartRateBPMMin, 0)
        XCTAssertEqual(aggregates.sessionHeartRateBPMMax, 0)
        XCTAssertEqual(aggregates.cadenceSPM30sWindow, 0)
        XCTAssertEqual(aggregates.cadenceSPM60sWindow, 0)
        XCTAssertEqual(aggregates.distanceMeters, 0)
        XCTAssertEqual(aggregates.strideLengthMPS, 0)
        XCTAssertEqual(aggregates.sessionElevationGainMeters, 0)
        XCTAssertEqual(aggregates.elevationGainMeters30sWindow, 0)
        XCTAssertEqual(aggregates.gradePercentage10sWindow, 0)
        XCTAssertEqual(aggregates.gradeAdjustedPace60sWindow, 0)
    }

    // MARK: - Single Metric Point Tests

    func testSinglePointAllZeros() {
        let data: [String: Any] = [
            "heartRate": 0.0,
            "distance": 0.0,
            "stepCount": 0.0,
            "activeEnergy": 0.0,
            "runningPower": 0.0,
            "runningSpeed": 0.0,
            "timestamp": startedAt.timeIntervalSince1970,
            "startedAt": startedAt.timeIntervalSince1970,
        ]
        preprocessor.addMetrics(data, 0)

        let aggregates = preprocessor.getAggregates()
        XCTAssertEqual(aggregates.sessionDuration, 0)
        XCTAssertEqual(aggregates.powerWatts30sWindowAverage, 0)
        XCTAssertEqual(aggregates.sessionPowerWattsAverage, 0)
        XCTAssertEqual(aggregates.paceMinutesPerKm30sWindowAverage, 0)
        XCTAssertEqual(aggregates.paceMinutesPerKm60sWindowAverage, 0)
        XCTAssertEqual(aggregates.paceMinutesPerKm60sWindowRateOfChange, 0)
        XCTAssertEqual(aggregates.sessionPaceMinutesPerKmAverage, 0)
        XCTAssertEqual(aggregates.heartRateBPM30sWindowAverage, 0)
        XCTAssertEqual(aggregates.heartRateBPM60sWindowAverage, 0)
        XCTAssertEqual(aggregates.heartRateBPM60sWindowRateOfChange, 0)
        XCTAssertEqual(aggregates.sessionHeartRateBPMAverage, 0)
        XCTAssertEqual(aggregates.sessionHeartRateBPMMin, 0)
        XCTAssertEqual(aggregates.sessionHeartRateBPMMax, 0)
        XCTAssertEqual(aggregates.cadenceSPM30sWindow, 0)
        XCTAssertEqual(aggregates.cadenceSPM60sWindow, 0)
        XCTAssertEqual(aggregates.distanceMeters, 0)
        XCTAssertEqual(aggregates.strideLengthMPS, 0)
        XCTAssertEqual(aggregates.sessionElevationGainMeters, 0)
        XCTAssertEqual(aggregates.elevationGainMeters30sWindow, 0)
        XCTAssertEqual(aggregates.gradePercentage10sWindow, 0)
        XCTAssertEqual(aggregates.gradeAdjustedPace60sWindow, 0)
    }

    func testSinglePointConstantValues() {
        let data: [String: Any] = [
            "heartRate": 150.0,
            "distance": 100.0,
            "stepCount": 50.0,
            "activeEnergy": 10.0,
            "runningPower": 200.0,
            "runningSpeed": 3.0,
            "timestamp": startedAt.addingTimeInterval(1).timeIntervalSince1970,
            "startedAt": startedAt.timeIntervalSince1970,
        ]
        preprocessor.addMetrics(data, 0)

        let aggregates = preprocessor.getAggregates()
        XCTAssertEqual(aggregates.sessionDuration, 1.0)
        XCTAssertEqual(aggregates.heartRateBPM30sWindowAverage, 150.0)
        XCTAssertEqual(aggregates.heartRateBPM60sWindowAverage, 150.0)
        XCTAssertEqual(aggregates.heartRateBPM60sWindowRateOfChange, 0)
        XCTAssertEqual(aggregates.sessionHeartRateBPMAverage, 150.0)
        XCTAssertEqual(aggregates.sessionHeartRateBPMMin, 150.0)
        XCTAssertEqual(aggregates.sessionHeartRateBPMMax, 150.0)
        XCTAssertEqual(aggregates.powerWatts30sWindowAverage, 200.0)
        XCTAssertEqual(aggregates.sessionPowerWattsAverage, 200.0)
        XCTAssertEqual(aggregates.paceMinutesPerKm30sWindowAverage, 5.56, accuracy: 0.01) // 1000/3/60
        XCTAssertEqual(aggregates.paceMinutesPerKm60sWindowAverage, 5.56, accuracy: 0.01)
        XCTAssertEqual(aggregates.paceMinutesPerKm60sWindowRateOfChange, 0)
        XCTAssertEqual(aggregates.sessionPaceMinutesPerKmAverage, 5.56, accuracy: 0.01)
        XCTAssertEqual(aggregates.cadenceSPM30sWindow, 0.0) // Needs more time to calculate
        XCTAssertEqual(aggregates.cadenceSPM60sWindow, 0.0)
        XCTAssertEqual(aggregates.distanceMeters, 100.0)
        XCTAssertEqual(aggregates.strideLengthMPS, 2.0) // 100m / 50 steps
        XCTAssertEqual(aggregates.sessionElevationGainMeters, 0)
        XCTAssertEqual(aggregates.elevationGainMeters30sWindow, 0)
        XCTAssertEqual(aggregates.gradePercentage10sWindow, 0)
        XCTAssertEqual(aggregates.gradeAdjustedPace60sWindow, 5.56, accuracy: 0.01) // Same as pace since grade is 0
    }

    // MARK: - Two Point Tests

    func testTwoPointsIncreasing() {
        let data1: [String: Any] = [
            "heartRate": 150.0,
            "distance": 100.0,
            "stepCount": 50.0,
            "activeEnergy": 10.0,
            "runningPower": 200.0,
            "runningSpeed": 3.0,
            "timestamp": startedAt.timeIntervalSince1970,
            "startedAt": startedAt.timeIntervalSince1970,
        ]

        let data2: [String: Any] = [
            "heartRate": 160.0,
            "distance": 200.0,
            "stepCount": 100.0,
            "activeEnergy": 20.0,
            "runningPower": 220.0,
            "runningSpeed": 3.5,
            "timestamp": startedAt.addingTimeInterval(1).timeIntervalSince1970,
            "startedAt": startedAt.timeIntervalSince1970,
        ]

        preprocessor.addMetrics(data1, 0)
        preprocessor.addMetrics(data2, 0)

        let aggregates = preprocessor.getAggregates()
        XCTAssertEqual(aggregates.sessionDuration, 1.0)
        XCTAssertEqual(aggregates.heartRateBPM30sWindowAverage, 155.0)
        XCTAssertEqual(aggregates.heartRateBPM60sWindowAverage, 155.0)
        XCTAssertEqual(aggregates.heartRateBPM60sWindowRateOfChange, 0) // No previous window yet
        XCTAssertEqual(aggregates.sessionHeartRateBPMAverage, 155.0)
        XCTAssertEqual(aggregates.sessionHeartRateBPMMin, 150.0)
        XCTAssertEqual(aggregates.sessionHeartRateBPMMax, 160.0)
        XCTAssertEqual(aggregates.powerWatts30sWindowAverage, 210.0)
        XCTAssertEqual(aggregates.sessionPowerWattsAverage, 210.0)
        XCTAssertEqual(aggregates.paceMinutesPerKm30sWindowAverage, 5.15, accuracy: 0.01) // (1000/3/60 + 1000/3.5/60) / 2
        XCTAssertEqual(aggregates.paceMinutesPerKm60sWindowAverage, 5.15, accuracy: 0.01)
        XCTAssertEqual(aggregates.paceMinutesPerKm60sWindowRateOfChange, 0) // No previous window yet
        XCTAssertEqual(aggregates.sessionPaceMinutesPerKmAverage, 5.15, accuracy: 0.01)
        XCTAssertEqual(aggregates.cadenceSPM30sWindow, 6000.0) // 100 steps / 1 second * 60
        XCTAssertEqual(aggregates.cadenceSPM60sWindow, 6000.0)
        XCTAssertEqual(aggregates.distanceMeters, 200.0)
        XCTAssertEqual(aggregates.strideLengthMPS, 2.0) // 100m / 50 steps
        XCTAssertEqual(aggregates.sessionElevationGainMeters, 0)
        XCTAssertEqual(aggregates.elevationGainMeters30sWindow, 0)
        XCTAssertEqual(aggregates.gradePercentage10sWindow, 0)
        XCTAssertEqual(aggregates.gradeAdjustedPace60sWindow, 5.15, accuracy: 0.01) // Same as pace since grade is 0
    }

    // MARK: - Window-based Tests

    func testFixedWindowMeanSanity() {
        let now = startedAt

        // Inject flat HR = 120 for 30s
        for i in 0 ..< 30 {
            preprocessor.addMetrics([
                "heartRate": 120.0,
                "runningSpeed": 2.0,
                "timestamp": now.addingTimeInterval(Double(i)).timeIntervalSince1970,
                "startedAt": now.timeIntervalSince1970,
            ], 1.0)
        }

        let aggregates = preprocessor.getAggregates()
        XCTAssertEqual(aggregates.heartRateBPM30sWindowAverage, 120.0)
        XCTAssertEqual(aggregates.paceMinutesPerKm30sWindowAverage, 8.33, accuracy: 0.01)
    }

    func testWindowTransitionAcrossMetrics() {
        let now = startedAt

        // Phase 1: Increasing (0–29s)
        for i in 0 ..< 30 {
            preprocessor.addMetrics([
                "heartRate": 120.0 + Double(i),
                "runningSpeed": 2.0 + Double(i) * 0.05,
                "timestamp": now.addingTimeInterval(Double(i)).timeIntervalSince1970,
                "startedAt": now.timeIntervalSince1970,
            ], 1.0)
        }

        // Phase 2: Decreasing (30–59s)
        for i in 30 ..< 60 {
            let j = i - 30
            preprocessor.addMetrics([
                "heartRate": 150.0 - Double(j),
                "runningSpeed": 3.5 - Double(j) * 0.05,
                "timestamp": now.addingTimeInterval(Double(i)).timeIntervalSince1970,
                "startedAt": now.timeIntervalSince1970,
            ], 0.0)
        }

        // Phase 3: Steady (60–89s) → 30s of fully flat values for clean window
        for i in 60 ..< 90 {
            preprocessor.addMetrics([
                "heartRate": 120.0,
                "runningSpeed": 2.0,
                "timestamp": now.addingTimeInterval(Double(i)).timeIntervalSince1970,
                "startedAt": now.timeIntervalSince1970,
            ], 0.0)
        }

        let aggregates = preprocessor.getAggregates()

        // Session duration should now be 89s
        XCTAssertEqual(aggregates.sessionDuration, 89.0)

        // Last 30s window: now purely from steady phase
        XCTAssertEqual(aggregates.heartRateBPM30sWindowAverage, 120.0, accuracy: 0.1)
        XCTAssertEqual(aggregates.paceMinutesPerKm30sWindowAverage, 8.33, accuracy: 0.01)

        // Last 60s window: 30s decreasing + 30s steady
        // Decreasing phase: 150 to 120 over 30s = average of 135
        // Steady phase: 120 for 30s
        // Combined average: (135 + 120) / 2 = 127.5
        XCTAssertEqual(aggregates.heartRateBPM60sWindowAverage, 127.5, accuracy: 1.0)

        // Full session heart rate average
        // Phase 1 (0-29s): 120 to 149 = average ~134.5
        // Phase 2 (30-59s): 150 to 120 = average ~135
        // Phase 3 (60-89s): 120 steady
        // Overall average: (134.5 * 30 + 135 * 30 + 120 * 30) / 90 ≈ 130.0
        XCTAssertEqual(aggregates.sessionHeartRateBPMAverage, 130.0, accuracy: 0.1)
        XCTAssertEqual(aggregates.sessionHeartRateBPMMin, 120.0)
        XCTAssertEqual(aggregates.sessionHeartRateBPMMax, 150.0)
    }

    // MARK: - HR rate of change

    func testHeartRateFluctuationRateOfChange() {
        let first = [
            "heartRate": 140.0,
            "timestamp": startedAt.timeIntervalSince1970,
            "startedAt": startedAt.timeIntervalSince1970,
        ]
        let second = [
            "heartRate": 160.0,
            "timestamp": startedAt.addingTimeInterval(60).timeIntervalSince1970,
            "startedAt": startedAt.timeIntervalSince1970,
        ]

        preprocessor.addMetrics(first, 0)
        preprocessor.addMetrics(second, 0)

        let aggregates = preprocessor.getAggregates()

        XCTAssertEqual(aggregates.heartRateBPM60sWindowRateOfChange, 20.0, accuracy: 0.1) // or whatever the logic dictates
    }

    // MARK: - Grade and GAP Tests

    func testGradeCalculation() {
        let data1: [String: Any] = [
            "heartRate": 150.0,
            "distance": 100.0,
            "stepCount": 50.0,
            "activeEnergy": 10.0,
            "runningPower": 200.0,
            "runningSpeed": 3.0,
            "timestamp": startedAt.timeIntervalSince1970,
            "startedAt": startedAt.timeIntervalSince1970,
        ]

        let data2: [String: Any] = [
            "heartRate": 160.0,
            "distance": 200.0,
            "stepCount": 100.0,
            "activeEnergy": 20.0,
            "runningPower": 220.0,
            "runningSpeed": 3.0,
            "timestamp": startedAt.addingTimeInterval(1).timeIntervalSince1970,
            "startedAt": startedAt.timeIntervalSince1970,
        ]

        preprocessor.addMetrics(data1, 0)
        preprocessor.addMetrics(data2, 10) // 10m elevation gain over 100m distance = 10% grade

        let aggregates = preprocessor.getAggregates()
        XCTAssertEqual(aggregates.gradePercentage10sWindow, 10.0, accuracy: 0.1)
        // For 10% grade, GAP should be adjusted by factor of 1.0 + (0.03 * 10) + (0.0005 * 10 * 10) = 1.35
        let expectedGAP = 5.56 * 1.35 // Base pace * grade adjustment factor
        XCTAssertEqual(aggregates.gradeAdjustedPace60sWindow, expectedGAP, accuracy: 0.01)
    }

    func testGradeAdjustedPaceWithIncline() {
        let data: [String: Any] = [
            "runningSpeed": 3.0,
            "distance": 100.0,
            "stepCount": 50.0,
            "timestamp": startedAt.addingTimeInterval(1).timeIntervalSince1970,
            "startedAt": startedAt.timeIntervalSince1970,
            "elevation": 5.0, // Assume this is interpreted and processed as an incline
        ]

        preprocessor.addMetrics(data, 0)

        let aggregates = preprocessor.getAggregates()

        XCTAssertGreaterThan(aggregates.gradeAdjustedPace60sWindow, aggregates.paceMinutesPerKm60sWindowAverage)
    }

    // MARK: - Real-world Scenario Tests

    func testTypicalRunningSession() {
        let now = startedAt

        // Warm-up phase (5 minutes)
        for i in 0 ..< 300 {
            let data: [String: Any] = [
                "heartRate": 120.0 + Double(i) * 0.1, // Gradually increasing HR
                "distance": Double(i) * 2.0, // 2 m/s pace
                "stepCount": Double(i) * 1.5,
                "activeEnergy": Double(i) * 0.1,
                "runningPower": 150.0 + Double(i) * 0.2,
                "runningSpeed": 2.0 + Double(i) * 0.01, // Gradually increasing speed
                "timestamp": now.addingTimeInterval(Double(i)).timeIntervalSince1970,
                "startedAt": now.timeIntervalSince1970,
            ]
            preprocessor.addMetrics(data, Double(i) * 0.1) // Gradual elevation gain
        }

        let aggregates = preprocessor.getAggregates()
        XCTAssertEqual(aggregates.sessionDuration, 299.0)
        // Heart rate should be around the average of start (120) and end (150)
        XCTAssertEqual(aggregates.heartRateBPM30sWindowAverage, 135.0, accuracy: 1.0)
        XCTAssertEqual(aggregates.heartRateBPM60sWindowAverage, 135.0, accuracy: 1.0)
        XCTAssertEqual(aggregates.sessionHeartRateBPMAverage, 135.0, accuracy: 1.0)
        XCTAssertEqual(aggregates.sessionHeartRateBPMMin, 120.0)
        XCTAssertEqual(aggregates.sessionHeartRateBPMMax, 150.0)
        // Power should be around the average of start (150) and end (210)
        XCTAssertEqual(aggregates.powerWatts30sWindowAverage, 180.0, accuracy: 1.0)
        XCTAssertEqual(aggregates.sessionPowerWattsAverage, 180.0, accuracy: 1.0)
        // Pace should be around 8.33 min/km (2 m/s)
        XCTAssertEqual(aggregates.paceMinutesPerKm30sWindowAverage, 8.33, accuracy: 0.1)
        XCTAssertEqual(aggregates.paceMinutesPerKm60sWindowAverage, 8.33, accuracy: 0.1)
        XCTAssertEqual(aggregates.sessionPaceMinutesPerKmAverage, 8.33, accuracy: 0.1)
        // Cadence should be around 90 spm (1.5 steps/second * 60)
        XCTAssertEqual(aggregates.cadenceSPM30sWindow, 90.0, accuracy: 1.0)
        XCTAssertEqual(aggregates.cadenceSPM60sWindow, 90.0, accuracy: 1.0)
        // Distance should be 598m (299 seconds * 2 m/s)
        XCTAssertEqual(aggregates.distanceMeters, 598.0, accuracy: 1.0)
        // Stride length should be around 1.33m (2m/s / 1.5 steps/s)
        XCTAssertEqual(aggregates.strideLengthMPS, 1.33, accuracy: 0.01)
        // Elevation gain should be around 29.9m (299 seconds * 0.1 m/s)
        XCTAssertEqual(aggregates.sessionElevationGainMeters, 29.9, accuracy: 0.1)
        XCTAssertEqual(aggregates.elevationGainMeters30sWindow, 3.0, accuracy: 0.1)
        // Grade should be around 5% (0.1 m/s elevation gain / 2 m/s horizontal speed)
        XCTAssertEqual(aggregates.gradePercentage10sWindow, 5.0, accuracy: 0.1)
        // GAP should be adjusted for 5% grade
        let expectedGAP = 8.33 * (1.0 + (0.03 * 5.0) + (0.0005 * 5.0 * 5.0))
        XCTAssertEqual(aggregates.gradeAdjustedPace60sWindow, expectedGAP, accuracy: 0.1)
    }
}
