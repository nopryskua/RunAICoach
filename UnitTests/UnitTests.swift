//
//  UnitTests.swift
//  UnitTests
//
//  Created by Nestor Oprysk on 5/8/25.
//

@testable import RunAICoach
import XCTest

final class UnitTests: XCTestCase {
    var preprocessor: MetricsPreprocessor!

    override func setUpWithError() throws {
        preprocessor = MetricsPreprocessor()
    }

    override func tearDownWithError() throws {
        preprocessor = nil
    }

    func testMetricsCollection() {
        // Add three sets of metrics
        preprocessor.addMetrics(
            heartRate: 120,
            distance: 1000,
            stepCount: 1000,
            activeEnergy: 100,
            elevation: 10,
            runningPower: 200,
            runningSpeed: 3.5
        )

        preprocessor.addMetrics(
            heartRate: 125,
            distance: 2000,
            stepCount: 2000,
            activeEnergy: 200,
            elevation: 15,
            runningPower: 210,
            runningSpeed: 3.6
        )

        preprocessor.addMetrics(
            heartRate: 130,
            distance: 3000,
            stepCount: 3000,
            activeEnergy: 300,
            elevation: 20,
            runningPower: 220,
            runningSpeed: 3.7
        )

        // Get preprocessed metrics
        let processedMetrics = preprocessor.getPreprocessedMetrics()

        // Assert that we have all three points
        XCTAssertEqual(processedMetrics.count, 3, "Should have exactly 3 metric points")

        // Verify the values of the first point
        let firstPoint = processedMetrics[0]
        XCTAssertEqual(firstPoint.heartRate, 120)
        XCTAssertEqual(firstPoint.distance, 1000)
        XCTAssertEqual(firstPoint.stepCount, 1000)
        XCTAssertEqual(firstPoint.activeEnergy, 100)
        XCTAssertEqual(firstPoint.elevation, 10)
        XCTAssertEqual(firstPoint.runningPower, 200)
        XCTAssertEqual(firstPoint.runningSpeed, 3.5)

        // Verify the values of the last point
        let lastPoint = processedMetrics[2]
        XCTAssertEqual(lastPoint.heartRate, 130)
        XCTAssertEqual(lastPoint.distance, 3000)
        XCTAssertEqual(lastPoint.stepCount, 3000)
        XCTAssertEqual(lastPoint.activeEnergy, 300)
        XCTAssertEqual(lastPoint.elevation, 20)
        XCTAssertEqual(lastPoint.runningPower, 220)
        XCTAssertEqual(lastPoint.runningSpeed, 3.7)
    }

    func testClearMetrics() {
        // Add some metrics
        preprocessor.addMetrics(
            heartRate: 120,
            distance: 1000,
            stepCount: 1000,
            activeEnergy: 100,
            elevation: 10,
            runningPower: 200,
            runningSpeed: 3.5
        )

        // Clear metrics
        preprocessor.clear()

        // Verify metrics are cleared
        let processedMetrics = preprocessor.getPreprocessedMetrics()
        XCTAssertEqual(processedMetrics.count, 0, "Should have no metric points after clearing")
    }
}
