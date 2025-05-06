//
//  HealthKitManager.swift
//  RunAICoachWatch Watch App
//
//  Created by Nestor Oprysk on 5/3/25.
//

import WatchConnectivity
import os.log

// MARK: - HealthKit Manager
class HealthKitManager: NSObject, ObservableObject {
    // MARK: - Properties
    private let healthKitCollector = HealthKitMetricsCollector()
    private let pedometerManager = PedometerManager()
    private let logger = Logger(subsystem: "com.runaicoach", category: "HealthKit")
    private var metricsUpdateTimer: Timer?
    private let metricsUpdateInterval: TimeInterval = 1.0
    
    // MARK: - Published Properties
    @Published private(set) var heartRate: Double = 0
    @Published private(set) var distance: Double = 0
    @Published private(set) var stepCount: Double = 0
    @Published private(set) var activeEnergy: Double = 0
    @Published private(set) var runningPower: Double = 0
    @Published private(set) var runningSpeed: Double = 0
    @Published private(set) var isWorkoutActive = false
    @Published private(set) var startedAt: Date?
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupWatchConnectivity()
        setupMetricsCollectors()
        requestAuthorization()
    }
    
    deinit {
        stopWorkout()
        metricsUpdateTimer?.invalidate()
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
    
    private func setupMetricsCollectors() {
        healthKitCollector.onMetricsUpdate = { [weak self] metrics in
            DispatchQueue.main.async {
                if let hr = metrics["heartRate"] { self?.heartRate = hr }
                if let dist = metrics["distance"] { self?.distance = dist }
                if let energy = metrics["activeEnergy"] { self?.activeEnergy = energy }
                if let power = metrics["runningPower"] { self?.runningPower = power }
                if let speed = metrics["runningSpeed"] { self?.runningSpeed = speed }
            }
        }
        
        pedometerManager.onStepCountUpdate = { [weak self] count in
            DispatchQueue.main.async {
                self?.stepCount = count
            }
        }
    }
    
    func requestAuthorization() {
        healthKitCollector.requestAuthorization()
    }
    
    // MARK: - Workout Control
    func startWorkout() {
        guard !isWorkoutActive else {
            logger.warning("Attempted to start workout while one is already active")
            return
        }
        
        if let startDate = healthKitCollector.startWorkout() {
            startedAt = startDate
            isWorkoutActive = true
            startMetricsTimer()
            pedometerManager.startTracking()
        }
    }
    
    func stopWorkout() {
        guard isWorkoutActive else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isWorkoutActive = false
            self.metricsUpdateTimer?.invalidate()
            self.metricsUpdateTimer = nil
            
            self.healthKitCollector.stopWorkout()
            self.pedometerManager.stopTracking()
            
            // Send final state update
            self.sendMetrics()
        }
    }
    
    // MARK: - Private Methods
    private func startMetricsTimer() {
        metricsUpdateTimer = Timer.scheduledTimer(withTimeInterval: metricsUpdateInterval, repeats: true) { [weak self] _ in
            self?.sendMetrics()
        }
    }
    
    private func sendMetrics() {
        let session = WCSession.default

        guard session.isReachable else {
            logger.error("WCSession is not reachable")
            return
        }
        
        let metrics: [String: Any] = [
            "startedAt": startedAt?.timeIntervalSince1970 ?? 0,
            "timestamp": Date().timeIntervalSince1970,
            "heartRate": heartRate,
            "distance": distance,
            "activeEnergy": activeEnergy,
            "stepCount": stepCount,
            "runningPower": runningPower,
            "runningSpeed": runningSpeed,
            "isWorkoutActive": isWorkoutActive
        ]
        
        // Try to update application context first
        do {
            try session.updateApplicationContext(metrics)
            logger.debug("Updated application context with metrics")
        } catch {
            logger.error("Failed to update application context: \(error.localizedDescription)")
        }
        
        // Also send as a message for immediate delivery
        session.sendMessage(metrics, replyHandler: nil) { [weak self] error in
            self?.logger.error("Failed to send metrics: \(error.localizedDescription)")
        }
    }
}

// MARK: - WCSessionDelegate
extension HealthKitManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            logger.error("WatchConnectivity activation failed: \(error.localizedDescription)")
        } else {
            logger.info("WatchConnectivity activated: \(activationState.rawValue)")
        }
    }
}
