//
//  PhoneSessionManager.swift
//  RunAICoach
//
//  Created by Nestor Oprysk on 5/3/25.
//

import os.log
import WatchConnectivity

class PhoneSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    // MARK: - Properties

    static let shared = PhoneSessionManager()
    private let logger = Logger(subsystem: "com.runaicoach", category: "PhoneSession")
    private let speechManager = SpeechManager()
    private var metricsTimer: Timer?
    private let metricsUpdateInterval: TimeInterval = 120.0
    private var isSpeaking = false
    private let elevationTracker = BarometricElevationTracker()
    private let metricsPreprocessor = MetricsPreprocessor()

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

    override private init() {
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

    func session(_: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            logger.error("WCSession activation failed: \(error.localizedDescription)")
        } else {
            logger.info("WCSession activated: \(activationState.rawValue)")
        }
    }

    func sessionDidBecomeInactive(_: WCSession) {
        logger.info("WCSession became inactive")
    }

    func sessionDidDeactivate(_: WCSession) {
        logger.info("WCSession deactivated")
        // Reactivate session if needed
        WCSession.default.activate()
    }

    func session(_: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handleReceivedData(applicationContext)
    }

    func session(_: WCSession, didReceiveMessage message: [String: Any]) {
        handleReceivedData(message)
    }

    private func handleReceivedData(_ data: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.handleWorkoutState(data)
            self.updateMetrics(data)

            // Log received data for debugging
            self.logger.debug("Received data: \(data)")
        }
    }

    private func handleWorkoutState(_ data: [String: Any]) {
        guard let isActive = data["isWorkoutActive"] as? Bool else { return }

        let wasActive = isWorkoutActive
        isWorkoutActive = isActive

        if !isActive && wasActive {
            handleWorkoutEnd()
        } else if isActive && !wasActive {
            handleWorkoutStart()
        }
    }

    private func handleWorkoutEnd() {
        // Reset all metrics
        heartRate = 0
        distance = 0
        stepCount = 0
        activeEnergy = 0
        elevation = 0
        runningPower = 0
        runningSpeed = 0
        lastUpdateTime = nil
        startedAt = nil
        isSpeaking = false

        // Stop services
        speechManager.stopSpeaking()
        metricsTimer?.invalidate()
        metricsTimer = nil
        elevationTracker.stopTracking()
        
        // Clear preprocessor data
        metricsPreprocessor.clear()
    }

    private func handleWorkoutStart() {
        setupMetricsTimer()
        elevationTracker.startTracking()
    }

    private func updateMetrics(_ data: [String: Any]) {
        if let heartRate = data["heartRate"] as? Double {
            self.heartRate = heartRate
        }
        if let distance = data["distance"] as? Double {
            self.distance = distance
        }
        if let stepCount = data["stepCount"] as? Double {
            self.stepCount = stepCount
        }
        if let energy = data["activeEnergy"] as? Double {
            activeEnergy = energy
        }
        if let power = data["runningPower"] as? Double {
            runningPower = power
        }
        if let speed = data["runningSpeed"] as? Double {
            runningSpeed = speed
        }
        if let timestamp = data["timestamp"] as? TimeInterval {
            lastUpdateTime = Date(timeIntervalSince1970: timestamp)
        }
        if let startTime = data["startedAt"] as? TimeInterval {
            startedAt = Date(timeIntervalSince1970: startTime)
        }
        
        // TODO: Input data with startedAt and timestamp

        // Add metrics to preprocessor
        metricsPreprocessor.addMetrics(
            heartRate: heartRate,
            distance: distance,
            stepCount: stepCount,
            activeEnergy: activeEnergy,
            elevation: elevation,
            runningPower: runningPower,
            runningSpeed: runningSpeed
        )
    }

    private func speakCurrentMetrics() {
        guard isWorkoutActive, !isSpeaking else { return }

        isSpeaking = true
        let metricsText = formatMetricsForSpeech()
        speechManager.speak(metricsText)

        // Reset speaking flag after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.isSpeaking = false
        }
    }

    private func formatMetricsForSpeech() -> String {
        return String(
            format: "Current heart rate is %d bpm, distance covered is %.2f kilometers, " +
                "step count is %d steps, energy burned is %.0f calories, " +
                "elevation change is %.1f meters, running power is %d W, " +
                "and running speed is %d m/s.",
            Int(heartRate),
            distance / 1000,
            Int(stepCount),
            activeEnergy,
            elevation,
            Int(runningPower),
            Int(runningSpeed)
        )
    }
}
