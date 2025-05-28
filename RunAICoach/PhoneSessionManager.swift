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
    private let speechManager: SpeechManager
    private var feedbackLoopTimer: Timer?
    private let elevationTracker = BarometricElevationTracker()
    private var lastElevation: Double?
    private let metricsPreprocessor = MetricsPreprocessor()
    private var feedbackManager: FeedbackManager!
    private var isExecutingFeedbackLoop = false

    // MARK: - Published Properties

    @Published private(set) var isWorkoutActive = false

    // MARK: - Initialization

    override init() {
        // Try to get API key from Config, fallback to nil if not available
        let apiKey = try? Config.openAIApiKey
        speechManager = SpeechManager(openAIApiKey: apiKey)

        super.init()

        // Create rules in order of evaluation
        let rules: [FeedbackRule] = [
            WorkoutStateRule(
                isWorkoutActive: { [weak self] in self?.isWorkoutActive ?? false },
                isExecutingFeedbackLoop: { [weak self] in self?.isExecutingFeedbackLoop ?? false }
            ),
            InitialFeedbackRule(),
            FirstKilometerRule(),
            KilometerRule(),
            PaceChangeRule(),
            HeartRateChangeRule(),
            ElevationChangeRule(),
            MaxTimeRule(),
        ]

        // Initialize feedback manager with rules and trigger function
        feedbackManager = FeedbackManager(rules: rules) { [weak self] current, rawMetrics, history in
            guard let self = self else { return "No metrics available" }

            // Generate feedback text based on current metrics and history
            let feedback = self.generateFeedback(current: current, rawMetrics: rawMetrics, history: history)

            // Speak the feedback
            self.speakFeedback(feedback)

            // Return the text for history
            return feedback
        }

        setupWatchConnectivity()
        setupElevationTracker()
    }

    deinit {
        feedbackLoopTimer?.invalidate()
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

    private func setupFeedbackLoop() {
        feedbackLoopTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            self.isExecutingFeedbackLoop = true
            defer { self.isExecutingFeedbackLoop = false }

            self.feedbackManager.maybeTriggerFeedback(
                current: self.metricsPreprocessor.getAggregates(),
                rawMetrics: self.metricsPreprocessor.getLatestMetrics()
            )
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
        // Stop services
        speechManager.stopSpeaking()
        feedbackLoopTimer?.invalidate()
        feedbackLoopTimer = nil
        elevationTracker.stopTracking()
        metricsPreprocessor.clear()
    }

    private func handleWorkoutStart() {
        setupFeedbackLoop()
        elevationTracker.startTracking()
    }

    private func updateMetrics(_ data: [String: Any]) {
        // Add metrics to preprocessor
        metricsPreprocessor.addMetrics(data, lastElevation)
    }

    private func speakFeedback(_ text: String) {
        speechManager.speak(text)
    }

    private func generateFeedback(current: Aggregates, rawMetrics _: MetricPoint?, history _: [Feedback]) -> String {
        // TODO: Call API with metrics to get text
        guard let jsonData = try? JSONEncoder().encode(current) else {
            return "Failed to encode metrics"
        }

        let jsonString = String(data: jsonData, encoding: .utf8)
        return jsonString ?? "No metrics available"
    }

    func getLatestMetrics() -> MetricPoint? {
        return metricsPreprocessor.getLatestMetrics()
    }
}
