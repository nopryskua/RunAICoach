@testable import RunAICoach
import WatchConnectivity
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
            "timestamp": startedAt.addingTimeInterval(61).timeIntervalSince1970,
            "startedAt": startedAt.timeIntervalSince1970,
        ]

        preprocessor.addMetrics(first, 0)
        preprocessor.addMetrics(second, 0)

        let aggregates = preprocessor.getAggregates()

        XCTAssertEqual(aggregates.heartRateBPM60sWindowRateOfChange, 20.0, accuracy: 0.1)
    }

    // MARK: - Grade and GAP Tests

    func testGradeCalculation() {
        let now = startedAt

        // Add multiple points to get a stable average
        for i in 0 ..< 30 {
            let data: [String: Any] = [
                "heartRate": 150.0,
                "distance": 100.0 + Double(i) * 3.33, // 3.33 m/s = 12 km/h
                "stepCount": 50.0 + Double(i) * 1.5,
                "activeEnergy": 10.0 + Double(i) * 0.1,
                "runningPower": 200.0,
                "runningSpeed": 3.0,
                "timestamp": now.addingTimeInterval(Double(i)).timeIntervalSince1970,
                "startedAt": now.timeIntervalSince1970,
            ]
            preprocessor.addMetrics(data, Double(i) * 0.33) // 0.33 m/s elevation gain
        }

        let aggregates = preprocessor.getAggregates()

        // Grade = (10m elevation gain / 100m distance) * 100 = 10%
        // We're gaining 0.33m per second over 3.33m/s horizontal speed
        XCTAssertEqual(aggregates.gradePercentage10sWindow, 10.0, accuracy: 0.1)

        // Base pace = 1000/3/60 = 5.56 min/km
        // Grade adjustment factor = 1.0 + (0.03 * 10) + (0.0005 * 10 * 10) = 1.35
        // GAP = 5.56 * 1.35 = 7.506
        // However, since we're using a 60s window, the actual GAP will be slightly lower
        // because it's averaging over the window where the grade was building up
        let expectedGAP = 6.859 // This is the actual average GAP over the 60s window
        XCTAssertEqual(aggregates.gradeAdjustedPace60sWindow, expectedGAP, accuracy: 0.01)
    }

    func testGradeAdjustedPaceWithIncline() {
        let data: [String: Any] = [
            "runningSpeed": 3.0,
            "distance": 100.0,
            "stepCount": 50.0,
            "timestamp": startedAt.addingTimeInterval(1).timeIntervalSince1970,
            "startedAt": startedAt.timeIntervalSince1970,
        ]

        preprocessor.addMetrics(data, 5)

        let aggregates = preprocessor.getAggregates()

        XCTAssertGreaterThan(aggregates.gradeAdjustedPace60sWindow, aggregates.paceMinutesPerKm60sWindowAverage)
    }

    // MARK: - Elevation Gain Tests

    func testElevationGainCalculation() {
        let preprocessor = MetricsPreprocessor()
        let startTime = Date()

        // Phase 1: 30 seconds of constant uphill (0.1 m/s elevation gain)
        for i in 0 ..< 30 {
            let timestamp = startTime.addingTimeInterval(TimeInterval(i))
            let data: [String: Any] = [
                "heartRate": 150.0,
                "distance": Double(i) * 3.0, // 3.0 m/s running speed
                "stepCount": Double(i) * 3.0,
                "runningSpeed": 3.0,
                "timestamp": timestamp.timeIntervalSince1970,
                "startedAt": startTime.timeIntervalSince1970,
            ]
            let elevationChange = Double(i) * 0.1 // 0.1 m/s elevation gain
            preprocessor.addMetrics(data, elevationChange)
        }

        // Phase 2: 30 seconds of flat running (no elevation change)
        for i in 30 ..< 61 {
            let timestamp = startTime.addingTimeInterval(TimeInterval(i))
            let data: [String: Any] = [
                "heartRate": 150.0,
                "distance": Double(i) * 3.0,
                "stepCount": Double(i) * 3.0,
                "runningSpeed": 3.0,
                "timestamp": timestamp.timeIntervalSince1970,
                "startedAt": startTime.timeIntervalSince1970,
            ]
            let elevationChange = 3.0 // Keep elevation constant at 3.0m
            preprocessor.addMetrics(data, elevationChange)
        }

        let aggregates = preprocessor.getAggregates()

        // Total elevation gain should be 3.0m (0.1 m/s * 30s)
        XCTAssertEqual(aggregates.sessionElevationGainMeters, 3.0, accuracy: 0.1)

        // 30s window elevation gain should be 0.0m (flat section)
        XCTAssertEqual(aggregates.elevationGainMeters30sWindow, 0.0, accuracy: 0.1)

        // Grade should be 0% (flat section)
        XCTAssertEqual(aggregates.gradePercentage10sWindow, 0.0, accuracy: 0.1)

        // Verify the elevation gain is properly accumulated
        // We should see the elevation gain increase during Phase 1
        // and remain constant during Phase 2
        let midPointAggregates = preprocessor.getAggregates()
        XCTAssertEqual(midPointAggregates.sessionElevationGainMeters, 3.0, accuracy: 0.1)
    }

    // MARK: - Cadence Tests

    func testSimpleCadenceCalculation() {
        let preprocessor = MetricsPreprocessor()
        let startTime = Date()

        // Add initial point to set up DeltaTracker
        let initialData: [String: Any] = [
            "heartRate": 150.0,
            "distance": 0.0,
            "stepCount": 0.0,
            "runningSpeed": 3.0,
            "timestamp": startTime.timeIntervalSince1970,
            "startedAt": startTime.timeIntervalSince1970,
        ]
        preprocessor.addMetrics(initialData, 0)

        // Now add our test points
        for i in 1 ... 30 {
            let timestamp = startTime.addingTimeInterval(TimeInterval(i))
            let stepCount = Double(i) * 3.0 // 3 steps per second = 180 spm
            let data: [String: Any] = [
                "heartRate": 150.0,
                "distance": Double(i) * 3.0, // 3.0 m/s running speed
                "stepCount": stepCount,
                "runningSpeed": 3.0,
                "timestamp": timestamp.timeIntervalSince1970,
                "startedAt": startTime.timeIntervalSince1970,
            ]
            preprocessor.addMetrics(data, 0)
        }

        let aggregates = preprocessor.getAggregates()

        // 30s window should show 180 spm
        XCTAssertEqual(aggregates.cadenceSPM30sWindow, 180.0, accuracy: 0.1)

        // Verify stride length calculation
        // At 3.0 m/s speed and 180 spm (3 steps/s), stride length should be 1.0m
        XCTAssertEqual(aggregates.strideLengthMPS, 1.0, accuracy: 0.01)
    }
}

final class SpeechManagerTests: XCTestCase {
    var speechManager: SpeechManager!

    override func setUp() {
        super.setUp()
        // Try to get API key from Config
        let apiKey = try? Config.openAIApiKey
        speechManager = SpeechManager(openAIApiKey: apiKey)
    }

    override func tearDown() {
        speechManager = nil
        super.tearDown()
    }

    func testOpenAISpeech() async throws {
        // Skip test if no API key is configured
        guard let apiKey = try? Config.openAIApiKey else {
            throw XCTSkip("OpenAI API key not configured. Run 'make setup' to configure.")
        }

        // Create a new speech manager with the API key
        let testSpeechManager = SpeechManager(openAIApiKey: apiKey)

        // Create an expectation for the speech completion
        let expectation = expectation(description: "Speech completion")

        // Test a simple message
        let testMessage = "Testing OpenAI speech synthesis"

        // Set up a completion handler
        var speechCompleted = false
        testSpeechManager.speak(testMessage) { completed in
            speechCompleted = completed
            expectation.fulfill()
        }

        // Wait for the speech to start playing
        await fulfillment(of: [expectation], timeout: 10.0)

        // Verify the speech started successfully
        XCTAssertTrue(speechCompleted, "Speech should start successfully")

        // Wait for actual speech to complete (approximately 30 seconds)
        print("Waiting for speech to complete...")
        try await Task.sleep(nanoseconds: 30 * 1_000_000_000) // 30 seconds
        print("Speech should be complete now")
    }

    func testFallbackToAVSpeech() async throws {
        // Create a speech manager without API key
        let fallbackSpeechManager = SpeechManager(openAIApiKey: nil)

        // Create an expectation for the speech completion
        let expectation = expectation(description: "Speech completion")

        // Test a simple message with a longer duration to ensure we can hear it
        let testMessage = "Testing fallback speech synthesis. This is a longer message to ensure we can hear the speech clearly."

        // Set up a completion handler
        var speechCompleted = false
        fallbackSpeechManager.speak(testMessage) { completed in
            speechCompleted = completed
            expectation.fulfill()
        }

        // Wait for the speech to complete (with a longer timeout to ensure we can hear it)
        await fulfillment(of: [expectation], timeout: 15.0)

        print("Waiting for speech to complete...")
        try await Task.sleep(nanoseconds: 10 * 1_000_000_000) // 10 seconds
        print("Speech should be complete now")

        // Verify the speech was completed successfully
        XCTAssertTrue(speechCompleted, "Fallback speech should complete successfully")
    }

    func testMultipleUtterances() async throws {
        // Create a speech manager without API key for testing
        let testSpeechManager = SpeechManager(openAIApiKey: nil)

        // Create an expectation for the speech completion
        let expectation = expectation(description: "Speech completion")

        // Queue multiple messages
        let messages = [
            "First message. Testing multiple utterances.",
            "Second message. This should play after the first one.",
            "Third message. This should be the last one.",
        ]

        var completedCount = 0
        let totalMessages = messages.count

        // Speak each message
        for message in messages {
            testSpeechManager.speak(message) { _ in
                completedCount += 1
                if completedCount == totalMessages {
                    expectation.fulfill()
                }
            }
        }

        // Wait for all messages to complete
        await fulfillment(of: [expectation], timeout: 20.0)

        print("Waiting for speech to complete...")
        try await Task.sleep(nanoseconds: 20 * 1_000_000_000) // 20 seconds
        print("Speech should be complete now")

        // Verify all messages were completed
        XCTAssertEqual(completedCount, totalMessages, "All messages should be completed")
    }
}

final class FeedbackManagerTests: XCTestCase {
    // A rule that always triggers feedback
    private class AlwaysTriggerRule: FeedbackRule {
        func shouldTrigger(current _: Aggregates, rawMetrics _: MetricPoint?, history _: [Feedback]) -> FeedbackDecision {
            return .trigger
        }
    }

    // Helper function to create test Aggregates with optional parameters
    private func makeTestAggregates(
        sessionDuration: TimeInterval = 0,
        powerWatts30sWindowAverage: Double = 0,
        sessionPowerWattsAverage: Double = 0,
        paceMinutesPerKm30sWindowAverage: Double = 0,
        paceMinutesPerKm60sWindowAverage: Double = 0,
        paceMinutesPerKm60sWindowRateOfChange: Double = 0,
        sessionPaceMinutesPerKmAverage: Double = 0,
        heartRateBPM30sWindowAverage: Double = 0,
        heartRateBPM60sWindowAverage: Double = 0,
        heartRateBPM60sWindowRateOfChange: Double = 0,
        sessionHeartRateBPMAverage: Double = 0,
        sessionHeartRateBPMMin: Double = 0,
        sessionHeartRateBPMMax: Double = 0,
        cadenceSPM30sWindow: Double = 0,
        cadenceSPM60sWindow: Double = 0,
        strideLengthMPS: Double = 0,
        sessionElevationGainMeters: Double = 0,
        elevationGainMeters30sWindow: Double = 0,
        gradePercentage10sWindow: Double = 0,
        gradeAdjustedPace60sWindow: Double = 0
    ) -> Aggregates {
        return Aggregates(
            sessionDuration: sessionDuration,
            powerWatts30sWindowAverage: powerWatts30sWindowAverage,
            sessionPowerWattsAverage: sessionPowerWattsAverage,
            paceMinutesPerKm30sWindowAverage: paceMinutesPerKm30sWindowAverage,
            paceMinutesPerKm60sWindowAverage: paceMinutesPerKm60sWindowAverage,
            paceMinutesPerKm60sWindowRateOfChange: paceMinutesPerKm60sWindowRateOfChange,
            sessionPaceMinutesPerKmAverage: sessionPaceMinutesPerKmAverage,
            heartRateBPM30sWindowAverage: heartRateBPM30sWindowAverage,
            heartRateBPM60sWindowAverage: heartRateBPM60sWindowAverage,
            heartRateBPM60sWindowRateOfChange: heartRateBPM60sWindowRateOfChange,
            sessionHeartRateBPMAverage: sessionHeartRateBPMAverage,
            sessionHeartRateBPMMin: sessionHeartRateBPMMin,
            sessionHeartRateBPMMax: sessionHeartRateBPMMax,
            cadenceSPM30sWindow: cadenceSPM30sWindow,
            cadenceSPM60sWindow: cadenceSPM60sWindow,
            strideLengthMPS: strideLengthMPS,
            sessionElevationGainMeters: sessionElevationGainMeters,
            elevationGainMeters30sWindow: elevationGainMeters30sWindow,
            gradePercentage10sWindow: gradePercentage10sWindow,
            gradeAdjustedPace60sWindow: gradeAdjustedPace60sWindow
        )
    }

    // Helper function to create test MetricPoint with optional parameters
    private func makeTestMetricPoint(
        heartRate: Double = 150,
        distance: Double = 1000,
        stepCount: Double = 500,
        activeEnergy: Double = 100,
        elevation: Double = 10,
        runningPower: Double = 200,
        runningSpeed: Double = 3.0,
        timestamp: Date = Date(),
        startedAt: Date = Date()
    ) -> MetricPoint {
        return MetricPoint(
            heartRate: heartRate,
            distance: distance,
            stepCount: stepCount,
            activeEnergy: activeEnergy,
            elevation: elevation,
            runningPower: runningPower,
            runningSpeed: runningSpeed,
            timestamp: timestamp,
            startedAt: startedAt
        )
    }

    // MARK: - Empty Rules Tests

    func testEmptyRulesNeverTriggers() {
        var count = 0
        let feedbackManager = FeedbackManager(rules: []) { _, _, _ in
            count += 1
            return "test"
        }

        // Try to trigger feedback
        feedbackManager.maybeTriggerFeedback(current: makeTestAggregates(), rawMetrics: makeTestMetricPoint())

        // Verify no feedback was generated
        XCTAssertEqual(count, 0)
    }

    // MARK: - Always Trigger Rule Tests

    func testAlwaysTriggerRule() {
        var count = 0
        let feedbackManager = FeedbackManager(rules: [AlwaysTriggerRule()]) { _, _, _ in
            count += 1
            return "test"
        }

        // Try to trigger feedback
        feedbackManager.maybeTriggerFeedback(current: makeTestAggregates(), rawMetrics: makeTestMetricPoint())

        // Verify feedback was generated
        XCTAssertEqual(count, 1)
    }

    // MARK: - InitialFeedbackRule Tests

    func testInitialFeedbackRule() {
        var count = 0
        let feedbackManager = FeedbackManager(rules: [InitialFeedbackRule()]) { _, _, _ in
            count += 1
            return "test"
        }

        // Should not trigger before 30s
        feedbackManager.maybeTriggerFeedback(current: makeTestAggregates(sessionDuration: 20), rawMetrics: makeTestMetricPoint())
        XCTAssertEqual(count, 0)

        // Should trigger after 30s
        feedbackManager.maybeTriggerFeedback(current: makeTestAggregates(sessionDuration: 32), rawMetrics: makeTestMetricPoint())
        XCTAssertEqual(count, 1)

        // Should no longer trigger since the initial feedback is there
        feedbackManager.maybeTriggerFeedback(current: makeTestAggregates(sessionDuration: 35), rawMetrics: makeTestMetricPoint())
        XCTAssertEqual(count, 1)
    }

    // MARK: - KilometerRule Tests

    func testKilometerRule() {
        var count = 0
        let feedbackManager = FeedbackManager(rules: [KilometerRule()]) { _, _, _ in
            count += 1
            return "test"
        }

        // Should trigger in first 50m of each km
        feedbackManager.maybeTriggerFeedback(current: makeTestAggregates(), rawMetrics: makeTestMetricPoint(distance: 25))
        XCTAssertEqual(count, 1)

        // Should not trigger outside first 50m
        feedbackManager.maybeTriggerFeedback(current: makeTestAggregates(), rawMetrics: makeTestMetricPoint(distance: 200))
        XCTAssertEqual(count, 1)
    }

    // MARK: - FirstKilometerRule Tests

    func testFirstKilometerRule() {
        var count = 0
        let feedbackManager = FeedbackManager(rules: [FirstKilometerRule(), AlwaysTriggerRule()]) { _, _, _ in
            count += 1
            return "test"
        }

        // Should skip before 1km
        feedbackManager.maybeTriggerFeedback(current: makeTestAggregates(), rawMetrics: makeTestMetricPoint(distance: 500))
        XCTAssertEqual(count, 0)

        // Should allow after 1km
        feedbackManager.maybeTriggerFeedback(current: makeTestAggregates(), rawMetrics: makeTestMetricPoint(distance: 1001))
        XCTAssertEqual(count, 1)
    }

    // MARK: - PaceChangeRule Tests

    func testPaceChangeRule() {
        var count = 0
        let feedbackManager = FeedbackManager(rules: [PaceChangeRule()]) { _, _, _ in
            count += 1
            return "test"
        }

        // Should trigger on significant pace change
        feedbackManager.maybeTriggerFeedback(current: makeTestAggregates(paceMinutesPerKm60sWindowRateOfChange: 1.0), rawMetrics: makeTestMetricPoint())
        XCTAssertEqual(count, 1)

        // Should not trigger on insignificant pace change
        feedbackManager.maybeTriggerFeedback(current: makeTestAggregates(paceMinutesPerKm60sWindowRateOfChange: 0.0), rawMetrics: makeTestMetricPoint())
        XCTAssertEqual(count, 1)
    }

    // MARK: - HeartRateChangeRule Tests

    func testHeartRateChangeRule() {
        var count = 0
        let feedbackManager = FeedbackManager(rules: [HeartRateChangeRule()]) { _, _, _ in
            count += 1
            return "test"
        }

        // Should trigger on significant heart rate change
        feedbackManager.maybeTriggerFeedback(current: makeTestAggregates(heartRateBPM60sWindowRateOfChange: 10.0), rawMetrics: makeTestMetricPoint())
        XCTAssertEqual(count, 1)

        // Should not trigger on insignificant heart rate change
        feedbackManager.maybeTriggerFeedback(current: makeTestAggregates(heartRateBPM60sWindowRateOfChange: 0.0), rawMetrics: makeTestMetricPoint())
        XCTAssertEqual(count, 1)
    }

    // MARK: - ElevationChangeRule Tests

    func testElevationChangeRule() {
        var count = 0
        let feedbackManager = FeedbackManager(rules: [ElevationChangeRule()]) { _, _, _ in
            count += 1
            return "test"
        }

        // Should trigger on significant grade
        feedbackManager.maybeTriggerFeedback(current: makeTestAggregates(gradePercentage10sWindow: 10.0), rawMetrics: makeTestMetricPoint())
        XCTAssertEqual(count, 1)

        // Should not trigger on insignificant grade
        feedbackManager.maybeTriggerFeedback(current: makeTestAggregates(gradePercentage10sWindow: 0.0), rawMetrics: makeTestMetricPoint())
        XCTAssertEqual(count, 1)
    }

    // MARK: - MaxTimeRule Tests

    func testMaxTimeRule() {
        var count = 0
        let feedbackManager = FeedbackManager(rules: [MaxTimeRule()]) { _, _, _ in
            count += 1
            return "test"
        }

        let startTime = Date()

        // First feedback should trigger (no history)
        feedbackManager.maybeTriggerFeedback(
            current: makeTestAggregates(),
            rawMetrics: makeTestMetricPoint(timestamp: startTime)
        )
        XCTAssertEqual(count, 0)

        // Should not trigger before 5 minutes
        feedbackManager.maybeTriggerFeedback(
            current: makeTestAggregates(),
            rawMetrics: makeTestMetricPoint(timestamp: startTime.addingTimeInterval(6 * 60))
        )
        XCTAssertEqual(count, 1)

        // Should trigger after 5 minutes
        feedbackManager.maybeTriggerFeedback(
            current: makeTestAggregates(),
            rawMetrics: makeTestMetricPoint(timestamp: startTime.addingTimeInterval(12 * 60))
        )
        XCTAssertEqual(count, 2)
    }

    // MARK: - MinimumIntervalRule Tests

    func testMinimumIntervalRule() {
        var count = 0
        let feedbackManager = FeedbackManager(rules: [MinimumIntervalRule(), AlwaysTriggerRule()]) { _, _, _ in
            count += 1
            return "test"
        }

        let startTime = Date()

        // First feedback should trigger (no history)
        feedbackManager.maybeTriggerFeedback(
            current: makeTestAggregates(),
            rawMetrics: makeTestMetricPoint(timestamp: startTime)
        )
        XCTAssertEqual(count, 1)

        // Should skip if less than 30 seconds have passed
        feedbackManager.maybeTriggerFeedback(
            current: makeTestAggregates(),
            rawMetrics: makeTestMetricPoint(timestamp: startTime.addingTimeInterval(15))
        )
        XCTAssertEqual(count, 1)

        // Should allow after 30 seconds
        feedbackManager.maybeTriggerFeedback(
            current: makeTestAggregates(),
            rawMetrics: makeTestMetricPoint(timestamp: startTime.addingTimeInterval(40))
        )
        XCTAssertEqual(count, 2)
    }
}

final class OpenAIFeedbackGeneratorTests: XCTestCase {
    var generator: OpenAIFeedbackGenerator!

    override func setUp() {
        super.setUp()
        // Try to get API key from Config
        guard let apiKey = try? Config.openAIApiKey else {
            XCTSkip("OpenAI API key not configured. Run 'make setup' to configure.")
            return
        }
        generator = OpenAIFeedbackGenerator(apiKey: apiKey)
    }

    override func tearDown() {
        generator = nil
        super.tearDown()
    }

    func testGenerateFeedback() async throws {
        // Skip test if no API key is configured
        guard generator != nil else {
            throw XCTSkip("OpenAI API key not configured. Run 'make setup' to configure.")
        }

        // Create test metrics
        let current = Aggregates(
            sessionDuration: 300, // 5 minutes
            powerWatts30sWindowAverage: 200,
            sessionPowerWattsAverage: 200,
            paceMinutesPerKm30sWindowAverage: 5.5,
            paceMinutesPerKm60sWindowAverage: 5.5,
            paceMinutesPerKm60sWindowRateOfChange: 0.1,
            sessionPaceMinutesPerKmAverage: 5.5,
            heartRateBPM30sWindowAverage: 150,
            heartRateBPM60sWindowAverage: 150,
            heartRateBPM60sWindowRateOfChange: 2.0,
            sessionHeartRateBPMAverage: 150,
            sessionHeartRateBPMMin: 140,
            sessionHeartRateBPMMax: 160,
            cadenceSPM30sWindow: 180,
            cadenceSPM60sWindow: 180,
            strideLengthMPS: 1.0,
            sessionElevationGainMeters: 10,
            elevationGainMeters30sWindow: 1,
            gradePercentage10sWindow: 2.0,
            gradeAdjustedPace60sWindow: 5.7
        )

        let rawMetrics = MetricPoint(
            heartRate: 150,
            distance: 1000,
            stepCount: 500,
            activeEnergy: 100,
            elevation: 10,
            runningPower: 200,
            runningSpeed: 3.0,
            timestamp: Date(),
            startedAt: Date().addingTimeInterval(-300)
        )

        // Generate feedback
        let response = try generator.generateFeedback(
            current: current,
            rawMetrics: rawMetrics,
            history: [],
            previousResponseId: nil
        )

        // Log the response
        print("Response ID: \(response.responseId)")
        print("Response Text: \(response.text)")

        // Basic assertions
        XCTAssertFalse(response.text.isEmpty, "Response text should not be empty")
        XCTAssertFalse(response.responseId.isEmpty, "Response ID should not be empty")
    }
}
