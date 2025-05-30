import Foundation
import os.log

struct OpenAIResponse {
    let text: String
    let responseId: String
}

class OpenAIFeedbackGenerator {
    private let apiKey: String
    private let model = "gpt-4o" // Best model for this use case
    private let maxOutputTokens = 100 // Short, focused responses for running feedback
    private let logger = Logger(subsystem: "com.runaicoach", category: "OpenAIFeedback")

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func generateFeedback(current: Aggregates, rawMetrics: MetricPoint?, history _: [Feedback], previousResponseId: String?) async throws -> OpenAIResponse {
        guard let url = URL(string: "https://api.openai.com/v1/responses") else {
            throw NSError(domain: "OpenAIFeedbackGenerator", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Prepare metrics as JSON
        var metricsJson: [String: Any] = [
            "current": [
                "sessionDuration": current.sessionDuration,
                "powerWatts30sWindowAverage": current.powerWatts30sWindowAverage,
                "sessionPowerWattsAverage": current.sessionPowerWattsAverage,
                "paceMinutesPerKm30sWindowAverage": current.paceMinutesPerKm30sWindowAverage,
                "paceMinutesPerKm60sWindowAverage": current.paceMinutesPerKm60sWindowAverage,
                "paceMinutesPerKm60sWindowRateOfChange": current.paceMinutesPerKm60sWindowRateOfChange,
                "sessionPaceMinutesPerKmAverage": current.sessionPaceMinutesPerKmAverage,
                "heartRateBPM30sWindowAverage": current.heartRateBPM30sWindowAverage,
                "heartRateBPM60sWindowAverage": current.heartRateBPM60sWindowAverage,
                "heartRateBPM60sWindowRateOfChange": current.heartRateBPM60sWindowRateOfChange,
                "sessionHeartRateBPMAverage": current.sessionHeartRateBPMAverage,
                "sessionHeartRateBPMMin": current.sessionHeartRateBPMMin,
                "sessionHeartRateBPMMax": current.sessionHeartRateBPMMax,
                "cadenceSPM30sWindow": current.cadenceSPM30sWindow,
                "cadenceSPM60sWindow": current.cadenceSPM60sWindow,
                "strideLengthMPS": current.strideLengthMPS,
                "sessionElevationGainMeters": current.sessionElevationGainMeters,
                "elevationGainMeters30sWindow": current.elevationGainMeters30sWindow,
                "gradePercentage10sWindow": current.gradePercentage10sWindow,
                "gradeAdjustedPace60sWindow": current.gradeAdjustedPace60sWindow,
            ],
        ]

        // Add raw metrics if available
        if let metrics = rawMetrics {
            metricsJson["rawMetrics"] = [
                "heartRate": metrics.heartRate,
                "distance": metrics.distance,
                "stepCount": metrics.stepCount,
                "activeEnergy": metrics.activeEnergy,
                "elevation": metrics.elevation,
                "runningPower": metrics.runningPower,
                "runningSpeed": metrics.runningSpeed,
                "timestamp": metrics.timestamp.timeIntervalSince1970,
                "startedAt": metrics.startedAt.timeIntervalSince1970,
            ]
        }

        // Convert metrics to JSON string
        let metricsJsonString = try String(data: JSONSerialization.data(withJSONObject: metricsJson), encoding: .utf8) ?? "{}"

        // Prepare the request body
        var body: [String: Any] = [
            "model": model,
            "instructions": """
            You are an AI running coach providing real-time feedback during a run. Your responses should be:
            1. Brief and focused (max 2-3 sentences)
            2. Contextually appropriate based on the session stage and metrics
            3. Specific to the current metrics and their trends
            4. Actionable when possible
            5. Encouraging and motivational

            Consider these scenarios and respond appropriately:
            - Session start (first feedback): Welcome the runner, acknowledge the start, and set a positive tone
            - Early session (first 5 minutes): Focus on establishing rhythm and comfort
            - Mid-session: Provide specific adjustments based on metrics
            - Milestones (e.g., kilometer markers): Acknowledge achievements
            - Challenging sections (elevation changes, pace drops): Offer specific guidance

            Key metrics to analyze and mention when relevant:
            - Pace changes: Comment on pace trends and suggest adjustments if needed
            - Heart rate zones: Note if heart rate is optimal for the current effort
            - Elevation changes: Acknowledge grade changes and suggest form adjustments
            - Power output: Comment on effort level and efficiency
            - Cadence: Note if stride rate is optimal

            Keep language simple and accessible. Focus on one key metric or adjustment at a time.
            Be encouraging but honest about what the metrics indicate.
            """,
            "input": metricsJsonString,
            "max_output_tokens": maxOutputTokens,
        ]

        // Only add previous_response_id if it exists
        if let previousResponseId = previousResponseId {
            body["previous_response_id"] = previousResponseId
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Make the API call
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "OpenAIFeedbackGenerator", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("OpenAI API error: \(errorMessage)")
            throw NSError(domain: "OpenAIFeedbackGenerator", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        // Parse the response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? String,
              let outputs = json["output"] as? [[String: Any]]
        else {
            throw NSError(domain: "OpenAIFeedbackGenerator", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
        }

        // Process all outputs and concatenate their text content
        let text = outputs.compactMap { output -> String? in
            guard let content = output["content"] as? [[String: Any]] else { return nil }

            // Get all text content from this output
            return content.compactMap { item -> String? in
                guard let type = item["type"] as? String,
                      type == "output_text",
                      let text = item["text"] as? String
                else { return nil }
                return text
            }.joined(separator: " ")
        }.joined(separator: " ")

        guard !text.isEmpty else {
            throw NSError(domain: "OpenAIFeedbackGenerator", code: -1, userInfo: [NSLocalizedDescriptionKey: "No text content in response"])
        }

        return OpenAIResponse(text: text, responseId: id)
    }
}
