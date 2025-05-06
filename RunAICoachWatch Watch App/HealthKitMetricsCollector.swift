//
//  HealthKitMetricsCollector.swift
//  RunAICoachWatch Watch App
//
//  Created by Nestor Oprysk on 5/6/25.
//

import HealthKit
import os.log

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
