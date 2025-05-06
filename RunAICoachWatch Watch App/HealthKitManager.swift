//
//  HealthKitManager.swift
//  RunAICoachWatch Watch App
//
//  Created by Nestor Oprysk on 5/3/25.
//

import HealthKit
import WatchConnectivity
import os.log
import CoreMotion

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
    @Published private(set) var workoutState: HKWorkoutSessionState = .notStarted
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

// MARK: - HealthKit Metrics Collector
class HealthKitMetricsCollector: NSObject {
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private let logger = Logger(subsystem: "com.runaicoach", category: "HealthKitMetrics")
    
    // Published metrics
    var onMetricsUpdate: ((_ metrics: [String: Double]) -> Void)?
    
    func requestAuthorization() {
        let types: Set<HKSampleType> = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .runningPower)!,
            HKQuantityType.quantityType(forIdentifier: .runningSpeed)!,
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
    
    func startWorkout() -> Date? {
        let config = HKWorkoutConfiguration()
        config.activityType = .running
        config.locationType = .outdoor
        
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            builder = session?.associatedWorkoutBuilder()
            
            session?.delegate = self
            builder?.delegate = self
            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
            
            let startDate = Date()
            session?.startActivity(with: startDate)
            builder?.beginCollection(withStart: startDate) { [weak self] success, error in
                if let error = error {
                    self?.logger.error("Failed to begin workout collection: \(error.localizedDescription)")
                    return
                }
                self?.logger.info("Workout collection started")
            }
            return startDate
        } catch {
            logger.error("Failed to start workout: \(error.localizedDescription)")
            return nil
        }
    }
    
    func stopWorkout() {
        session?.end()
        builder?.endCollection(withEnd: Date()) { [weak self] success, error in
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
    
    private func updateMetrics(from builder: HKLiveWorkoutBuilder, types: Set<HKSampleType>) {
        var metrics: [String: Double] = [:]
        
        for type in types {
            guard let qtyType = type as? HKQuantityType,
                  let stats = builder.statistics(for: qtyType) else {
                continue
            }
            
            switch qtyType {
            case HKQuantityType.quantityType(forIdentifier: .heartRate):
                if let val = stats.mostRecentQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) {
                    metrics["heartRate"] = val
                }
            case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning):
                if let val = stats.sumQuantity()?.doubleValue(for: HKUnit.meter()) {
                    metrics["distance"] = val
                }
            case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
                if let val = stats.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) {
                    metrics["activeEnergy"] = val
                }
            case HKQuantityType.quantityType(forIdentifier: .runningPower):
                if let val = stats.mostRecentQuantity()?.doubleValue(for: HKUnit.watt()) {
                    metrics["runningPower"] = val
                }
            case HKQuantityType.quantityType(forIdentifier: .runningSpeed):
                if let val = stats.mostRecentQuantity()?.doubleValue(for: HKUnit.meter().unitDivided(by: .second())) {
                    metrics["runningSpeed"] = val
                }
            default:
                break
            }
        }
        
        if !metrics.isEmpty {
            onMetricsUpdate?(metrics)
        }
    }
}

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

// MARK: - HKWorkoutSessionDelegate
extension HealthKitMetricsCollector: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                       from fromState: HKWorkoutSessionState, date: Date) {
        // Handle session state changes if needed
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        logger.error("Workout session failed: \(error.localizedDescription)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension HealthKitMetricsCollector: HKLiveWorkoutBuilderDelegate {
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
