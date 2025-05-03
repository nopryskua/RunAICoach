//
//  HealthKitManager.swift
//  RunAICoachWatch Watch App
//
//  Created by Nestor Oprysk on 5/3/25.
//

// TODO: Check if all imports necessary

import SwiftUI
import HealthKit
import Combine
import WatchConnectivity
import os.log
import WatchKit

class HealthKitManager: NSObject, ObservableObject {
    // MARK: - Properties
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private let logger = Logger(subsystem: "com.runaicoach", category: "HealthKit")
    private var metricsUpdateTimer: Timer?
    private let metricsUpdateInterval: TimeInterval = 1.0
    
    // MARK: - Published Properties
    @Published private(set) var heartRate: Double = 0
    @Published private(set) var distance: Double = 0
    @Published private(set) var isWorkoutActive = false
    @Published private(set) var workoutState: HKWorkoutSessionState = .notStarted
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupWatchConnectivity()
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
    
    func requestAuthorization() {
        let types: Set<HKSampleType> = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.workoutType()
        ]
        
        healthStore.requestAuthorization(toShare: types, read: types) { [weak self] success, error in
            if let error = error {
                self?.logger.error("HealthKit authorization failed: \(error.localizedDescription)")
            } else if success {
                self?.logger.info("HealthKit authorization granted")
            }
        }
    }
    
    // MARK: - Workout Control
    func startWorkout() {
        guard !isWorkoutActive else {
            logger.warning("Attempted to start workout while one is already active")
            return
        }
        
        let config = HKWorkoutConfiguration()
        config.activityType = .running
        config.locationType = .outdoor
        
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            builder = session?.associatedWorkoutBuilder()
            
            session?.delegate = self
            builder?.delegate = self
            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
            
            session?.startActivity(with: Date())
            builder?.beginCollection(withStart: Date()) { [weak self] success, error in
                if let error = error {
                    self?.logger.error("Failed to begin workout collection: \(error.localizedDescription)")
                    return
                }
                
                DispatchQueue.main.async {
                    self?.isWorkoutActive = true
                    self?.startMetricsTimer()
                }
            }
        } catch {
            logger.error("Failed to start workout: \(error.localizedDescription)")
        }
    }
    
    func stopWorkout() {
        guard isWorkoutActive else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isWorkoutActive = false
            self.metricsUpdateTimer?.invalidate()
            self.metricsUpdateTimer = nil
            
            // Send final state update
            let finalMsg: [String: Any] = [
                "heartRate": 0,
                "distance": 0,
                "timestamp": Date().timeIntervalSince1970,
                "isWorkoutActive": false
            ]
            
            do {
                try WCSession.default.updateApplicationContext(finalMsg)
            } catch {
                self.logger.error("Failed to update final application context: \(error.localizedDescription)")
            }
            
            self.session?.end()
            self.builder?.endCollection(withEnd: Date()) { [weak self] success, error in
                if let error = error {
                    self?.logger.error("Failed to end workout collection: \(error.localizedDescription)")
                    return
                }
                
                self?.builder?.finishWorkout { [weak self] workout, error in
                    if let error = error {
                        self?.logger.error("Failed to finish workout: \(error.localizedDescription)")
                    } else if let workout = workout {
                        self?.logger.info("Workout finished successfully: \(workout.duration) seconds")
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    private func startMetricsTimer() {
        metricsUpdateTimer = Timer.scheduledTimer(withTimeInterval: metricsUpdateInterval, repeats: true) { [weak self] _ in
            self?.sendMetrics()
        }
    }
    
    private func updateMetrics(from builder: HKLiveWorkoutBuilder, types: Set<HKSampleType>) {
        for type in types {
            guard let qtyType = type as? HKQuantityType,
                  let stats = builder.statistics(for: qtyType) else { continue }
            
            switch qtyType {
            case HKQuantityType.quantityType(forIdentifier: .heartRate):
                if let val = stats.mostRecentQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) {
                    DispatchQueue.main.async { [weak self] in
                        self?.heartRate = val
                    }
                }
            case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning):
                if let val = stats.sumQuantity()?.doubleValue(for: HKUnit.meter()) {
                    DispatchQueue.main.async { [weak self] in
                        self?.distance = val
                    }
                }
            default:
                break
            }
        }
    }
    
    private func sendMetrics() {
        guard WCSession.default.activationState == .activated,
              isWorkoutActive else {
            return
        }
        
        // Capture current values on the main thread
        let currentHeartRate = heartRate
        let currentDistance = distance
        
        let msg: [String: Any] = [
            "heartRate": currentHeartRate,
            "distance": currentDistance,
            "timestamp": Date().timeIntervalSince1970,
            "isWorkoutActive": isWorkoutActive
        ]
        
        // Try to update application context first
        do {
            try WCSession.default.updateApplicationContext(msg)
        } catch {
            logger.error("Failed to update application context: \(error.localizedDescription)")
        }
        
        // Also send as a message for immediate delivery
        WCSession.default.sendMessage(msg, replyHandler: nil) { [weak self] error in
            if let error = error as Error? {
                self?.logger.error("Failed to send metrics: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - HKWorkoutSessionDelegate
extension HealthKitManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                       from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async { [weak self] in
            self?.workoutState = toState
            
            // Handle session state changes
            switch toState {
            case .running:
                self?.logger.info("Workout session running")
            case .ended:
                self?.logger.info("Workout session ended")
                self?.stopWorkout()
            case .paused:
                self?.logger.info("Workout session paused")
            case .notStarted:
                self?.logger.info("Workout session not started")
            default:
                self?.logger.warning("Unknown workout session state: \(toState.rawValue)")
            }
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        logger.error("Workout session failed: \(error.localizedDescription)")
        stopWorkout()
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension HealthKitManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf types: Set<HKSampleType>) {
        updateMetrics(from: workoutBuilder, types: types)
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        if let event = workoutBuilder.workoutEvents.last {
            logger.info("Workout event: \(event.type.rawValue)")
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
