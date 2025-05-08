//
//  RunAICoachTests.swift
//  RunAICoachTests
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
        // TODO: Test
    }
}
