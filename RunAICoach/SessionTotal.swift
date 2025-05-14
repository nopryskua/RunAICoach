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

    init() {
        total = 0.0
        count = 0
    }

    mutating func add(_ value: Double) {
        total += value
        count += 1
    }

    func average() -> Double {
        guard count > 0 else { return 0 }
        return Double(total) / Double(count)
    }
}
