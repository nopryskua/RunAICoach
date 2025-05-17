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
    private let transform: (Double) -> Double

    init(interval: TimeInterval,
         previous: RollingWindow? = nil,
         transform: @escaping (Double) -> Double = { $0 } // Identity transform
    ) {
        window = Deque()
        self.interval = interval
        currentSum = 0.0
        self.previous = previous
        self.transform = transform
    }

    func add(value: Double, at timestamp: Date) {
        // Remove outdated values and consider for the previous window
        let cutoff = timestamp.addingTimeInterval(-interval)
        while let first = window.first, first.timestamp < cutoff {
            previous?.add(value: first.value, at: first.timestamp)
            currentSum -= first.value
            window.removeFirst()
        }

        // Apply transform to the value
        let transformedValue = transform(value)

        // Add new value
        window.append((timestamp, transformedValue))
        currentSum += transformedValue
    }

    func average() -> Double {
        guard !window.isEmpty else { return 0.0 }
        return currentSum / Double(window.count)
    }

    func sum() -> Double {
        return currentSum
    }

    func duration() -> TimeInterval {
        guard let last = window.last else { return 0.0 }
        return last.timestamp.timeIntervalSince(window.first?.timestamp ?? last.timestamp)
    }
}
