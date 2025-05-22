//
//  SessionTotal.swift
//  RunAICoach
//
//  Created by Nestor Oprysk on 5/14/25.
//

import Foundation

final class SessionTotal {
    private var sum: Double
    private var count: Int
    private var min: Double
    private var max: Double
    private let transform: (Double) -> Double

    init(transform: @escaping (Double) -> Double = { $0 }) {
        sum = 0.0
        count = 0
        min = 0.0
        max = 0.0
        self.transform = transform
    }

    func add(_ value: Double) {
        let transformedValue = transform(value)
        sum += transformedValue
        count += 1
        if count == 1 {
            min = transformedValue
            max = transformedValue
        } else {
            min = Swift.min(min, transformedValue)
            max = Swift.max(max, transformedValue)
        }
    }

    func average() -> Double {
        guard count > 0 else { return 0.0 }
        return sum / Double(count)
    }

    func getMin() -> Double {
        return min
    }

    func getMax() -> Double {
        return max
    }
}
