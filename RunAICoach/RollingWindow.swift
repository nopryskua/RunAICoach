//
//  RollingWindow.swift
//  RunAICoach
//
//  Created by Nestor Oprysk on 5/14/25.
//

import Collections
import Foundation

struct RollingWindow {
    private var window: Deque<(timestamp: Date, value: Double)>
    private let interval: TimeInterval
    private var currentSum: Double

    init(interval: TimeInterval) {
        window = Deque()
        self.interval = interval
        currentSum = 0.0
    }

    mutating func add(value: Double, at timestamp: Date) {
        // Remove outdated values
        let cutoff = timestamp.addingTimeInterval(-interval)
        while let first = window.first, first.timestamp < cutoff {
            currentSum -= first.value
            window.removeFirst()
        }

        // Add new value
        window.append((timestamp, value))
        currentSum += value
    }

    func average() -> Double {
        guard !window.isEmpty else { return 0.0 }
        return currentSum / Double(window.count)
    }

    var count: Int {
        return window.count
    }

    var sum: Double {
        return currentSum
    }
}
