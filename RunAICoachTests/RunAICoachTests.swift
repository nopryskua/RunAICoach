//
//  RunAICoachTests.swift
//  RunAICoachTests
//
//  Created by Nestor Oprysk on 5/8/25.
//

import XCTest
@testable import RunAICoach

final class UnitTests: XCTestCase {
    var preprocessor: MetricsPreprocessor!

    override func setUpWithError() throws {
        preprocessor = MetricsPreprocessor()
    }

    override func tearDownWithError() throws {
        preprocessor = nil
    }

    func testMetricsCollection() {
        preprocessor.addMetrics(
            heartRate: 120,
            distance: 1000,
            stepCount: 1000,
            activeEnergy: 100,
            elevation: 10,
            runningPower: 200,
            runningSpeed: 3.5
        )

        // Get preprocessed metrics
        let processedMetrics = preprocessor.getPreprocessedMetrics()

        // Assert that we have all three points
        XCTAssertEqual(processedMetrics.count, 1, "Should have exactly 1 metric point")
    }
}
