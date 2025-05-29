import Foundation

enum FeedbackDecision {
    case trigger // Yes, provide feedback
    case skip // No, don't provide feedback
    case next // Let the next rule decide
}

protocol FeedbackRule {
    func shouldTrigger(current: Aggregates, rawMetrics: MetricPoint?, history: [Feedback]) -> FeedbackDecision
}

struct Feedback {
    let timestamp: Date
    let content: String
    let ruleName: String
    let responseId: String?
}

class FeedbackManager {
    private let rules: [FeedbackRule]
    private var feedbackHistory: [Feedback] = []
    private let trigger: (Aggregates, MetricPoint?, [Feedback]) async throws -> String

    init(rules: [FeedbackRule], trigger: @escaping (Aggregates, MetricPoint?, [Feedback]) async throws -> String) {
        self.rules = rules
        self.trigger = trigger
    }

    func maybeTriggerFeedback(current: Aggregates, rawMetrics: MetricPoint?) {
        let now = Date()

        // Evaluate rules in order
        for rule in rules {
            switch rule.shouldTrigger(current: current, rawMetrics: rawMetrics, history: feedbackHistory) {
            case .trigger:
                // Create a task to handle async feedback generation
                Task {
                    do {
                        let content = try await trigger(current, rawMetrics, feedbackHistory)
                        let feedback = Feedback(
                            timestamp: now,
                            content: content,
                            ruleName: String(describing: type(of: rule)),
                            responseId: feedbackHistory.last?.responseId
                        )
                        feedbackHistory.append(feedback)
                    } catch {
                        // Log error and continue to next rule
                        print("Failed to generate feedback: \(error.localizedDescription)")
                    }
                }
                return

            case .skip:
                return

            case .next:
                continue
            }
        }
    }
}

class WorkoutStateRule: FeedbackRule {
    private let isWorkoutActive: () -> Bool
    private let isExecutingFeedbackLoop: () -> Bool

    init(isWorkoutActive: @escaping () -> Bool, isExecutingFeedbackLoop: @escaping () -> Bool) {
        self.isWorkoutActive = isWorkoutActive
        self.isExecutingFeedbackLoop = isExecutingFeedbackLoop
    }

    func shouldTrigger(current _: Aggregates, rawMetrics _: MetricPoint?, history _: [Feedback]) -> FeedbackDecision {
        // Skip if workout is not active
        guard isWorkoutActive() else { return .skip }

        // Skip if feedback loop is currently executing
        guard !isExecutingFeedbackLoop() else { return .skip }

        return .next
    }
}

class InitialFeedbackRule: FeedbackRule {
    private let minimumInterval: TimeInterval = 30 // 30 seconds before first feedback

    func shouldTrigger(current: Aggregates, rawMetrics _: MetricPoint?, history: [Feedback]) -> FeedbackDecision {
        guard current.sessionDuration > minimumInterval else { return .skip }

        if history.isEmpty {
            return .trigger
        }

        return .next
    }
}

class FirstKilometerRule: FeedbackRule {
    func shouldTrigger(current _: Aggregates, rawMetrics: MetricPoint?, history _: [Feedback]) -> FeedbackDecision {
        guard let metrics = rawMetrics else { return .skip }
        guard metrics.distance >= 1000 else { return .skip }

        return .next
    }
}

class KilometerRule: FeedbackRule {
    private let triggerWindow: Double = 50 // meters

    func shouldTrigger(current _: Aggregates, rawMetrics: MetricPoint?, history _: [Feedback]) -> FeedbackDecision {
        guard let metrics = rawMetrics else { return .skip }

        // Calculate current kilometer and remaining meters
        let totalMeters = metrics.distance
        let currentKilometer = floor(totalMeters / 1000)

        let metersInCurrentKilometer = totalMeters - (currentKilometer * 1000)

        // Trigger if we're in the first 50 meters of a kilometer
        if metersInCurrentKilometer <= triggerWindow {
            return .trigger
        }

        return .next
    }
}

class PaceChangeRule: FeedbackRule {
    private let paceChangeThreshold: Double = 0.5 // minutes per km

    func shouldTrigger(current: Aggregates, rawMetrics _: MetricPoint?, history _: [Feedback]) -> FeedbackDecision {
        // Check for significant pace changes
        if abs(current.paceMinutesPerKm60sWindowRateOfChange) > paceChangeThreshold {
            return .trigger
        }

        return .next
    }
}

class HeartRateChangeRule: FeedbackRule {
    private let heartRateChangeThreshold: Double = 5.0 // BPM

    func shouldTrigger(current: Aggregates, rawMetrics _: MetricPoint?, history _: [Feedback]) -> FeedbackDecision {
        // Check for significant heart rate changes
        if abs(current.heartRateBPM60sWindowRateOfChange) > heartRateChangeThreshold {
            return .trigger
        }

        return .next
    }
}

class ElevationChangeRule: FeedbackRule {
    private let gradeThreshold: Double = 5.0 // percentage

    func shouldTrigger(current: Aggregates, rawMetrics _: MetricPoint?, history _: [Feedback]) -> FeedbackDecision {
        // Check for significant grade changes
        if abs(current.gradePercentage10sWindow) > gradeThreshold {
            return .trigger
        }

        return .next
    }
}

class MaxTimeRule: FeedbackRule {
    private let maximumInterval: TimeInterval = 5 * 60 // 5 minutes maximum between feedbacks

    func shouldTrigger(current _: Aggregates, rawMetrics: MetricPoint?, history: [Feedback]) -> FeedbackDecision {
        // If we don't have raw metrics with timestamp, we can't make a decision
        guard let metrics = rawMetrics else { return .next }

        // If there's no history, use workout start time as reference
        let referenceTime: Date
        if let lastFeedback = history.last {
            referenceTime = lastFeedback.timestamp
        } else {
            referenceTime = metrics.startedAt
        }

        // Calculate time difference between reference time and current metrics
        let timeSinceReference = metrics.timestamp.timeIntervalSince(referenceTime)

        // Trigger if more than maximumInterval has passed
        if timeSinceReference > maximumInterval {
            return .trigger
        }

        return .next
    }
}
