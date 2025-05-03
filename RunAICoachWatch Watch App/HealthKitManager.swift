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

class HealthKitManager: NSObject, ObservableObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate, WCSessionDelegate {
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    @Published var heartRate: Double = 0
    @Published var distance: Double = 0

    override init() {
        super.init()
        // Activate WatchConnectivity session
        if WCSession.isSupported() {
            let wc = WCSession.default
            wc.delegate = self
            wc.activate()
        }
        requestAuthorization()
    }

    func requestAuthorization() {
        let types: Set<HKSampleType> = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.workoutType()
        ]
        healthStore.requestAuthorization(toShare: types, read: types) { success, error in
            if let error = error { print("HK Auth Error: \(error)") }
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
            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)

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
                if let error = error { print("Finish workout error: \(error)") }
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
        print("Workout event: \(workoutBuilder.workoutEvents.last?.type.rawValue ?? -1)")
    }

    private func updateMetrics(from builder: HKLiveWorkoutBuilder, types: Set<HKSampleType>) {
        for type in types {
            guard let qtyType = type as? HKQuantityType,
                  let stats = builder.statistics(for: qtyType) else { continue }
            switch qtyType {
            case HKQuantityType.quantityType(forIdentifier: .heartRate):
                if let val = stats.mostRecentQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) {
                    DispatchQueue.main.async { self.heartRate = val }
                }
            case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning):
                if let val = stats.sumQuantity()?.doubleValue(for: HKUnit.meter()) {
                    DispatchQueue.main.async { self.distance = val }
                }
            default: break
            }
        }
    }

    private func sendMetrics() {
        let msg: [String: Any] = ["heartRate": heartRate, "distance": distance]
        WCSession.default.sendMessage(msg, replyHandler: nil) { error in
            print("WC send error: \(error)")
        }
    }

    // MARK: WCSessionDelegate (watchOS)
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error { print("WC activation failed on watch: \(error)") }
        else { print("WC activated on watch: \(activationState.rawValue)") }
    }
}
