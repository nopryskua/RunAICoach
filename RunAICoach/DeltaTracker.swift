//
//  DeltaTracker.swift
//  RunAICoach
//
//  Created by Nestor Oprysk on 5/17/25.
//

import Foundation

final class DeltaTracker {
    private var previousValue: Double

    init() {
        previousValue = 0.0
    }

    func delta(_ value: Double) -> Double {
        defer { previousValue = value }

        return value - previousValue
    }

    func reset() {
        previousValue = 0.0
    }
}
