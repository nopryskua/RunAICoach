//
//  PhoneSesionManager.swift
//  RunAICoach
//
//  Created by Nestor Oprysk on 5/3/25.
//

import WatchConnectivity
import os.log
import CoreMotion

class PhoneSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    // MARK: - Properties
    static let shared = PhoneSessionManager()
    private let logger = Logger(subsystem: "com.runaicoach", category: "PhoneSession")
    private let speechManager = SpeechManager()
    private var metricsTimer: Timer?
    private let metricsUpdateInterval: TimeInterval = 120.0
    private var isSpeaking = false
    private let elevationTracker = BarometricElevationTracker()
    
    // MARK: - Published Properties
    @Published private(set) var heartRate: Double = 0
    @Published private(set) var distance: Double = 0
    @Published private(set) var stepCount: Double = 0
    @Published private(set) var activeEnergy: Double = 0
    @Published private(set) var elevation: Double = 0
    @Published private(set) var runningPower: Double = 0
    @Published private(set) var runningSpeed: Double = 0
    @Published private(set) var isWorkoutActive = false
    @Published private(set) var lastUpdateTime: Date?
    @Published private(set) var startedAt: Date?
    
    // MARK: - Initialization
    private override init() {
        super.init()
        setupWatchConnectivity()
        setupMetricsTimer()
        setupElevationTracker()
    }
    
    deinit {
        metricsTimer?.invalidate()
        speechManager.stopSpeaking()
        elevationTracker.stopTracking()
    }
    
    // MARK: - Setup
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            logger.error("WatchConnectivity is not supported")
            return
        }
        
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }
    
    private func setupMetricsTimer() {
        metricsTimer = Timer.scheduledTimer(withTimeInterval: metricsUpdateInterval, repeats: true) { [weak self] _ in
            self?.speakCurrentMetrics()
        }
    }
    
    private func setupElevationTracker() {
        elevationTracker.onElevationUpdate = { [weak self] elevation in
            DispatchQueue.main.async {
                self?.elevation = elevation
            }
        }
    }
    
    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            logger.error("WCSession activation failed: \(error.localizedDescription)")
        } else {
            logger.info("WCSession activated: \(activationState.rawValue)")
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        logger.info("WCSession became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        logger.info("WCSession deactivated")
        // Reactivate session if needed
        WCSession.default.activate()
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        handleReceivedData(applicationContext)
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleReceivedData(message)
    }
    
    private func handleReceivedData(_ data: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Update workout state
            if let isActive = data["isWorkoutActive"] as? Bool {
                let wasActive = self.isWorkoutActive
                self.isWorkoutActive = isActive
                
                if !isActive && wasActive {
                    // Workout just ended
                    self.heartRate = 0
                    self.distance = 0
                    self.stepCount = 0
                    self.activeEnergy = 0
                    self.elevation = 0
                    self.runningPower = 0
                    self.runningSpeed = 0
                    self.lastUpdateTime = nil
                    self.startedAt = nil
                    self.isSpeaking = false
                    // Stop any ongoing speech
                    self.speechManager.stopSpeaking()
                    // Invalidate timer
                    self.metricsTimer?.invalidate()
                    self.metricsTimer = nil
                    // Stop elevation tracking
                    self.elevationTracker.stopTracking()
                } else if isActive && !wasActive {
                    // Workout just started
                    self.setupMetricsTimer()
                    self.elevationTracker.startTracking()
                }
            }
            
            // Update metrics
            if let hr = data["heartRate"] as? Double {
                self.heartRate = hr
            }
            if let dist = data["distance"] as? Double {
                self.distance = dist
            }
            if let sc = data["stepCount"] as? Double {
                self.stepCount = sc
            }
            if let energy = data["activeEnergy"] as? Double {
                self.activeEnergy = energy
            }
            if let rp = data["runningPower"] as? Double {
                self.runningPower = rp
            }
            if let rs = data["runningSpeed"] as? Double {
                self.runningSpeed = rs
            }
            if let timestamp = data["timestamp"] as? TimeInterval {
                self.lastUpdateTime = Date(timeIntervalSince1970: timestamp)
            }
            if let startTime = data["startedAt"] as? TimeInterval {
                self.startedAt = Date(timeIntervalSince1970: startTime)
            }
            
            // Log received data for debugging
            self.logger.debug("Received data: \(data)")
        }
    }
    
    // MARK: - Private Methods
    private func speakCurrentMetrics() {
        guard isWorkoutActive, !isSpeaking else { return }
        
        isSpeaking = true
        let text = String(format: "Current heart rate is %d bpm, distance covered is %.2f kilometers, step count is %d steps, energy burned is %.0f calories, elevation change is %.1f meters, running power is %d W, and running speed is %d m/s.",
                         Int(heartRate),
                         distance / 1000,
                         Int(stepCount),
                         activeEnergy,
                         elevation,
                         Int(runningPower),
                         Int(runningSpeed))
        speechManager.speak(text)
        
        // Reset speaking flag after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.isSpeaking = false
        }
    }
}

// MARK: - Barometric Elevation Tracker
class BarometricElevationTracker: NSObject {
    private let altimeter = CMAltimeter()
    private let logger = Logger(subsystem: "com.runaicoach", category: "BarometricElevation")
    
    // Constants for elevation calculation
    private let R: Double = 8.31432       // J/(mol·K)
    private let M: Double = 0.0289644     // kg/mol
    private let g: Double = 9.80665       // m/s²
    private let T: Double = 288.15        // K (assumed constant)
    private let factor: Double            // ≈ 18406.5
    
    private var referencePressure: Double?  // in kPa
    private var isTracking = false
    
    var onElevationUpdate: ((_ elevation: Double) -> Void)?
    
    override init() {
        factor = (R * T) / (M * g)
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
                  let pressure = data?.pressure.doubleValue else {
                self?.logger.error("Failed to get pressure data: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            // CMAltimeter.pressure is in kilopascals (kPa)
            if self.referencePressure == nil {
                self.referencePressure = pressure
                self.logger.info("Set reference pressure: \(pressure) kPa")
            }
            
            let p0 = self.referencePressure!
            let p1 = pressure
            
            // Δh in meters
            let deltaH = self.factor * log(p0 / p1)
            
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
