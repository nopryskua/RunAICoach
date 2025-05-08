import Foundation
import os.log

struct MetricPoint {
    let timestamp: Date
    let heartRate: Double
    let distance: Double
    let stepCount: Double
    let activeEnergy: Double
    let elevation: Double
    let runningPower: Double
    let runningSpeed: Double
}

class MetricsPreprocessor {
    private var timeSeries: [MetricPoint] = []
    private let logger = Logger(subsystem: "com.runaicoach", category: "MetricsPreprocessor")
    
    func addMetrics(
        heartRate: Double,
        distance: Double,
        stepCount: Double,
        activeEnergy: Double,
        elevation: Double,
        runningPower: Double,
        runningSpeed: Double
    ) {
        let point = MetricPoint(
            timestamp: Date(),
            heartRate: heartRate,
            distance: distance,
            stepCount: stepCount,
            activeEnergy: activeEnergy,
            elevation: elevation,
            runningPower: runningPower,
            runningSpeed: runningSpeed
        )
        
        timeSeries.append(point)
        logger.debug("Added new metric point, total points: \(self.timeSeries.count)")
    }
    
    func getPreprocessedMetrics() -> [MetricPoint] {
        // For now, just return all collected metrics
        // TODO: Implement actual preprocessing logic
        return timeSeries
    }
    
    func clear() {
        timeSeries.removeAll()
    }
} 
