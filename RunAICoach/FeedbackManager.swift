//
//  FeedbackManager.swift
//  RunAICoach
//
//  Created by Nestor Oprysk on 5/26/25.
//

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
}

class FeedbackManager {
    private let rules: [FeedbackRule]
    private var feedbackHistory: [Feedback] = []
    private let trigger: (Aggregates, MetricPoint?, [Feedback]) -> String

    init(rules: [FeedbackRule], trigger: @escaping (Aggregates, MetricPoint?, [Feedback]) -> String) {
        self.rules = rules
        self.trigger = trigger
    }

    func maybeTriggerFeedback(current: Aggregates, rawMetrics: MetricPoint?) {
        let now = Date()

        // Evaluate rules in order
        for rule in rules {
            switch rule.shouldTrigger(current: current, rawMetrics: rawMetrics, history: feedbackHistory) {
            case .trigger:
                let content = trigger(current, rawMetrics, feedbackHistory)
                let feedback = Feedback(
                    timestamp: now,
                    content: content,
                    ruleName: String(describing: type(of: rule))
                )
                feedbackHistory.append(feedback)
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
