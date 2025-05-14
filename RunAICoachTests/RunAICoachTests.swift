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
        preprocessor = MetricsPreprocessor() // TODO: Use
    }

    override func tearDownWithError() throws {
        preprocessor = nil
    }

    // MARK: - RollingWindow Tests

    func testEmptyWindow() {
        let window = RollingWindow(interval: 10)
        XCTAssertEqual(window.average(), 0.0)
        XCTAssertEqual(window.count, 0)
        XCTAssertEqual(window.sum, 0.0)
    }

    func testBasicAddition() {
        var window = RollingWindow(interval: 10)
        let now = Date()

        window.add(value: 10.0, at: now)
        window.add(value: 20.0, at: now.addingTimeInterval(2))
        window.add(value: 30.0, at: now.addingTimeInterval(4))

        XCTAssertEqual(window.count, 3)
        XCTAssertEqual(window.sum, 60.0)
        XCTAssertEqual(window.average(), 20.0)
    }

    func testEvictionAfterInterval() {
        var window = RollingWindow(interval: 5)
        let now = Date()

        window.add(value: 10.0, at: now)
        window.add(value: 20.0, at: now.addingTimeInterval(2))
        window.add(value: 30.0, at: now.addingTimeInterval(6)) // Evicts 10.0

        XCTAssertEqual(window.count, 2)
        XCTAssertEqual(window.sum, 50.0)
        XCTAssertEqual(window.average(), 25.0)
    }

    func testMultipleEvictions() {
        var window = RollingWindow(interval: 5)
        let now = Date()

        window.add(value: 5.0, at: now)
        window.add(value: 10.0, at: now.addingTimeInterval(1))
        window.add(value: 15.0, at: now.addingTimeInterval(2))
        window.add(value: 20.0, at: now.addingTimeInterval(8)) // Should evict first three

        XCTAssertEqual(window.count, 1)
        XCTAssertEqual(window.sum, 20.0)
        XCTAssertEqual(window.average(), 20.0)
    }

    func testAllValuesEvicted() {
        var window = RollingWindow(interval: 3)
        let now = Date()

        window.add(value: 1.0, at: now)
        window.add(value: 2.0, at: now.addingTimeInterval(1))
        window.add(value: 3.0, at: now.addingTimeInterval(2))
        window.add(value: 4.0, at: now.addingTimeInterval(6)) // Evicts all previous

        XCTAssertEqual(window.count, 1)
        XCTAssertEqual(window.sum, 4.0)
        XCTAssertEqual(window.average(), 4.0)
    }

    func testPrecisionHandling() {
        var window = RollingWindow(interval: 10)
        let now = Date()

        window.add(value: 0.1, at: now)
        window.add(value: 0.2, at: now.addingTimeInterval(1))
        window.add(value: 0.3, at: now.addingTimeInterval(2))

        XCTAssertEqual(window.sum, 0.6, accuracy: 0.0001)
        XCTAssertEqual(window.average(), 0.2, accuracy: 0.0001)
    }

    // MARK: - SessionTotal Tests

    func testEmptySessionTotal() {
        let total = SessionTotal()
        XCTAssertEqual(total.average(), 0.0)
    }

    func testBasicSessionTotal() {
        var total = SessionTotal()

        total.add(1.0)
        total.add(3.0)

        XCTAssertEqual(total.average(), 2.0)
    }
}
