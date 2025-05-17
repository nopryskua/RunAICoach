//
//  RollingWindow.swift
//  RunAICoach
//
//  Created by Nestor Oprysk on 5/14/25.
//

import Collections
import Foundation

final class RollingWindow {
    private var window: Deque<(timestamp: Date, value: Double)>
    private let interval: TimeInterval
    private var currentSum: Double
    private weak var previous: RollingWindow?

    init(interval: TimeInterval, previous: RollingWindow? = nil) {
        window = Deque()
        self.interval = interval
        currentSum = 0.0
        self.previous = previous
    }

    func add(value: Double, at timestamp: Date) {
        // Remove outdated values and consider for the previous window
        let cutoff = timestamp.addingTimeInterval(-interval)
        while let first = window.first, first.timestamp < cutoff {
            previous?.add(value: first.value, at: first.timestamp)
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
}
