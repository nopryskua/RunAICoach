//
//  PedometerManager.swift
//  RunAICoachWatch Watch App
//
//  Created by Nestor Oprysk on 5/6/25.
//

import CoreMotion
import os.log

// MARK: - Pedometer Manager

class PedometerManager: NSObject {
    private var pedometer: CMPedometer?
    private var pedometerStartDate: Date?
    private let logger = Logger(subsystem: "com.runaicoach", category: "Pedometer")

    var onStepCountUpdate: ((_ stepCount: Double) -> Void)?

    func startTracking() {
        guard CMPedometer.isStepCountingAvailable() else {
            logger.error("Step counting is not available")
            return
        }

        pedometer = CMPedometer()
        pedometerStartDate = Date()

        // Get initial data
        pedometer?.queryPedometerData(from: pedometerStartDate!, to: Date()) { [weak self] data, error in
            guard let self = self, let data = data, error == nil else {
                self?.logger.error("Initial pedometer query failed: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            DispatchQueue.main.async {
                self.onStepCountUpdate?(data.numberOfSteps.doubleValue)
            }
        }

        // Start live updates
        pedometer?.startUpdates(from: pedometerStartDate!) { [weak self] data, error in
            guard let self = self, let data = data, error == nil else {
                self?.logger.error("Pedometer update failed: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            DispatchQueue.main.async {
                self.onStepCountUpdate?(data.numberOfSteps.doubleValue)
            }
        }
    }

    func stopTracking() {
        pedometer?.stopUpdates()
        pedometer = nil
        pedometerStartDate = nil
    }
}
