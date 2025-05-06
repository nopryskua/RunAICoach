//
//  BarometricElevationTracker.swift
//  RunAICoach
//
//  Created by Nestor Oprysk on 5/6/25.
//

import CoreMotion
import os.log

// MARK: - Barometric Elevation Tracker

class BarometricElevationTracker: NSObject {
    private let altimeter = CMAltimeter()
    private let logger = Logger(subsystem: "com.runaicoach", category: "BarometricElevation")

    // Constants for elevation calculation
    private let gasConstant: Double = 8.31432 // J/(mol·K)
    private let molarMass: Double = 0.0289644 // kg/mol
    private let gravity: Double = 9.80665 // m/s²
    private let temperature: Double = 288.15 // K (assumed constant)
    private let factor: Double // ≈ 18406.5

    private var referencePressure: Double? // in kPa
    private var isTracking = false

    var onElevationUpdate: ((_ elevation: Double) -> Void)?

    override init() {
        factor = (gasConstant * temperature) / (molarMass * gravity)
        super.init()
    }

    func startTracking() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            logger.error("Barometric altimeter is not available")
            return
        }

        isTracking = true
        referencePressure = nil

        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
            guard let self = self,
                  error == nil,
                  let pressure = data?.pressure.doubleValue
            else {
                self?.logger.error("Failed to get pressure data: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            // CMAltimeter.pressure is in kilopascals (kPa)
            if self.referencePressure == nil {
                self.referencePressure = pressure
                self.logger.info("Set reference pressure: \(pressure) kPa")
            }

            let initialPressure = self.referencePressure!
            let currentPressure = pressure

            // Δh in meters
            let deltaH = self.factor * log(initialPressure / currentPressure)

            self.logger.debug("Pressure: \(pressure) kPa, Elevation change: \(deltaH)m")
            self.onElevationUpdate?(deltaH)
        }

        logger.info("Started barometric elevation tracking")
    }

    func stopTracking() {
        guard isTracking else { return }

        altimeter.stopRelativeAltitudeUpdates()
        isTracking = false
        referencePressure = nil
        logger.info("Stopped barometric elevation tracking")
    }
}
