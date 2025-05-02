//
//  HealthKitManager.swift
//  RunAICoachWatch Watch App
//
//  Created by Nestor Oprysk on 5/3/25.
//

import SwiftUI
import HealthKit
import Combine
import WatchConnectivity

class HealthKitManager: NSObject, ObservableObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    @Published var heartRate: Double = 0
    @Published var distance: Double = 0

    override init() {
        super.init()
        requestAuthorization()
    }

    func requestAuthorization() {
        let readTypes: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.workoutType()
        ]
        healthStore.requestAuthorization(toShare: readTypes, read: readTypes) { success, error in
            if let error = error {
                print("HK Auth Error: \(error)")
            }
        }
    }

    func startWorkout() {
        let config = HKWorkoutConfiguration()
        config.activityType = .running
        config.locationType = .outdoor

        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            builder = session?.associatedWorkoutBuilder()
            session?.delegate = self
            builder?.delegate = self

            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore,
                                                         workoutConfiguration: config)

            session?.startActivity(with: Date())
            builder?.beginCollection(withStart: Date()) { _, _ in }
        } catch {
            print("Failed to start workout: \(error)")
        }
    }

    func stopWorkout() {
        session?.end()
        builder?.endCollection(withEnd: Date()) { _, _ in
            self.builder?.finishWorkout { _, error in
                if let error = error {
                    print("Finish workout error: \(error)")
                }
            }
        }
    }

    // MARK: HKWorkoutSessionDelegate
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState, date: Date) {}
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {}

    // MARK: HKLiveWorkoutBuilderDelegate
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf types: Set<HKSampleType>) {
        updateMetrics(from: workoutBuilder, types: types)
        sendMetrics()
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout builder events, e.g., pause, resume, lap
        // You can inspect workoutBuilder.workoutEvents here if needed
        print("WorkoutBuilder did collect event: \(workoutBuilder.workoutEvents.last?.type.rawValue ?? -1)")
    }

    private func updateMetrics(from builder: HKLiveWorkoutBuilder, types: Set<HKSampleType>) {
        for type in types {
            guard let quantityType = type as? HKQuantityType,
                  let statistics = builder.statistics(for: quantityType) else { continue }
            switch quantityType {
            case HKQuantityType.quantityType(forIdentifier: .heartRate):
                if let val = statistics.mostRecentQuantity()?.doubleValue(
                    for: HKUnit.count().unitDivided(by: HKUnit.minute())) {
                    DispatchQueue.main.async { self.heartRate = val }
                }
            case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning):
                if let val = statistics.sumQuantity()?.doubleValue(for: HKUnit.meter()) {
                    DispatchQueue.main.async { self.distance = val }
                }
            default:
                break
            }
        }
    }

    private func sendMetrics() {
        let message: [String: Any] = ["heartRate": heartRate, "distance": distance]
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("WC send error: \(error)")
        }
    }
}
