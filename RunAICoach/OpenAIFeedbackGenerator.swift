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

    func generateFeedback(current: Aggregates, rawMetrics: MetricPoint?, history _: [Feedback], previousResponseId: String?) throws -> OpenAIResponse {
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
            You are an elite running coach with Olympic-level experience, providing real-time guidance during a run. Your role is to be both a technical expert and a motivational partner. Your responses should be:
            1. Conversational and personal - speak directly to the runner as if you're running alongside them
            2. Brief and impactful (2-3 sentences max)
            3. Specific and actionable - give clear, immediate guidance
            4. Encouraging and empowering - celebrate progress and build confidence
            5. Contextually aware - adapt your tone and focus based on the run's stage

            Guide the runner through these key moments:
            - Start: "Welcome to your run! Let's start strong and find your rhythm."
            - Early minutes: "Focus on settling into a comfortable pace. How's your breathing feeling?"
            - Milestones: "Incredible work hitting that kilometer! Your form is looking strong."
            - Challenges: "I see that hill coming up. Let's shorten your stride and keep your cadence quick."

            When providing feedback, focus on one key aspect at a time:
            - For pace: "Your pace is dropping slightly. Let's pick it up with 3 quick strides."
            - For heart rate: "Your heart rate is climbing. Take a deep breath and relax your shoulders."
            - For elevation: "That's a steep grade ahead. Lean forward slightly and drive with your arms."
            - For power: "Your power output is strong! Keep that efficient stride going."
            - For cadence: "Your cadence is perfect right now. Let's maintain this rhythm."

            Use natural, encouraging language:
            - Instead of "Your heart rate is elevated": "I notice you're working hard. Let's take a moment to find your rhythm."
            - Instead of "Pace is below target": "We can pick up the pace a bit. Ready for a quick surge?"
            - Instead of "Elevation gain detected": "Here comes a challenge! Let's tackle this hill together."

            Remember:
            - Be their running partner, not just a data analyst
            - Celebrate small victories
            - Provide immediate, actionable adjustments
            - Keep the energy positive and motivating
            - Use natural, conversational language
            """,
            "input": metricsJsonString,
            "max_output_tokens": maxOutputTokens,
        ]

        // Only add previous_response_id if it exists
        if let previousResponseId = previousResponseId {
            body["previous_response_id"] = previousResponseId
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Create a semaphore to make the async call synchronous
        let semaphore = DispatchSemaphore(value: 0)
        var responseData: Data?
        var responseError: Error?
        var httpResponse: HTTPURLResponse?

        // Make the API call
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            responseData = data
            responseError = error
            httpResponse = response as? HTTPURLResponse
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()

        if let error = responseError {
            throw error
        }

        guard let data = responseData else {
            throw NSError(domain: "OpenAIFeedbackGenerator", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])
        }

        guard let httpResponse = httpResponse else {
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
