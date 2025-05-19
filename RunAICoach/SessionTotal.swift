//
//  SessionTotal.swift
//  RunAICoach
//
//  Created by Nestor Oprysk on 5/14/25.
//

import Foundation

struct SessionTotal {
    private var total: Double
    private var count: Int
    private var min: Double?
    private var max: Double?

    init() {
        total = 0.0
        count = 0
    }

    private mutating func updateMin(value: Double) {
        if min == nil {
            min = value

            return
        }

        if value < min! {
            min = value
        }
    }

    private mutating func updateMax(value: Double) {
        if max == nil {
            max = value

            return
        }

        if value > max! {
            max = value
        }
    }

    mutating func add(_ value: Double) {
        total += value
        count += 1

        updateMin(value: value)
        updateMax(value: value)
    }

    func average() -> Double {
        guard count > 0 else { return 0 }
        return total / Double(count)
    }

    func getMin() -> Double {
        guard count > 0 else { return 0 }
        return min!
    }

    func getMax() -> Double {
        guard count > 0 else { return 0 }
        return max!
    }
}
