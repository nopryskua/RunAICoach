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
    private var openAIFeedbackGenerator: OpenAIFeedbackGenerator?

    // MARK: - Published Properties

    @Published private(set) var isWorkoutActive = false

    // MARK: - Initialization

    override init() {
        // Try to get API key from Config, fallback to nil if not available
        let apiKey = try? Config.openAIApiKey
        speechManager = SpeechManager(openAIApiKey: apiKey)
        if let apiKey = apiKey {
            openAIFeedbackGenerator = OpenAIFeedbackGenerator(apiKey: apiKey)
        }

        super.init()

        // Create rules in order of evaluation
        let rules: [FeedbackRule] = [
            MinimumIntervalRule(),
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
            let feedback = try await self.generateFeedback(current: current, rawMetrics: rawMetrics, history: history)

            // Speak the feedback
            self.speakFeedback(feedback.text)

            // Return the text for history
            return feedback.text
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

            // Skip if workout is not active or feedback loop is executing
            guard self.isWorkoutActive && !self.isExecutingFeedbackLoop else { return }

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
        feedbackManager.reset()
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

    private func generateFeedback(current: Aggregates, rawMetrics: MetricPoint?, history: [Feedback]) async throws -> OpenAIResponse {
        // If we don't have an OpenAI API key, throw an error
        guard let generator = openAIFeedbackGenerator else {
            throw NSError(domain: "PhoneSessionManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "OpenAI API key not configured"])
        }

        // Generate feedback using the OpenAI generator
        return try await generator.generateFeedback(
            current: current,
            rawMetrics: rawMetrics,
            history: history,
            previousResponseId: history.last?.responseId
        )
    }

    func getLatestMetrics() -> MetricPoint? {
        return metricsPreprocessor.getLatestMetrics()
    }
}
