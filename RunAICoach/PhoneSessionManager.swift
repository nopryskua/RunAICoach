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
    private var lastElevation: Double?
    private let metricsPreprocessor = MetricsPreprocessor()

    // MARK: - Published Properties

    @Published private(set) var isWorkoutActive = false

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
                self?.lastElevation = elevation
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
        isSpeaking = false

        // Stop services
        speechManager.stopSpeaking()
        metricsTimer?.invalidate()
        metricsTimer = nil
        elevationTracker.stopTracking()
        metricsPreprocessor.clear()
    }

    private func handleWorkoutStart() {
        setupMetricsTimer()
        elevationTracker.startTracking()
    }

    private func updateMetrics(_ data: [String: Any]) {
        // Add metrics to preprocessor
        metricsPreprocessor.addMetrics(data, lastElevation)
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
        // TODO: Call API with metrics to get text
        let metrics = metricsPreprocessor.getPreprocessedMetrics()
        return String(
            format: "Collected %d metric points.",
            metrics.count
        )
    }

    func getLatestMetrics() -> MetricPoint? {
        return metricsPreprocessor.getLatestMetrics()
    }
}
