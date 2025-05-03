//
//  PhoneSesionManager.swift
//  RunAICoach
//
//  Created by Nestor Oprysk on 5/3/25.
//

import WatchConnectivity
import os.log

class PhoneSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    // MARK: - Properties
    static let shared = PhoneSessionManager()
    private let logger = Logger(subsystem: "com.runaicoach", category: "PhoneSession")
    private let speechManager = SpeechManager()
    private var metricsTimer: Timer?
    private let metricsUpdateInterval: TimeInterval = 15.0
    private var isSpeaking = false
    
    // MARK: - Published Properties
    @Published private(set) var heartRate: Double = 0
    @Published private(set) var distance: Double = 0
    @Published private(set) var isWorkoutActive = false
    @Published private(set) var lastUpdateTime: Date?
    
    // MARK: - Initialization
    private override init() {
        super.init()
        setupWatchConnectivity()
        setupMetricsTimer()
    }
    
    deinit {
        metricsTimer?.invalidate()
        speechManager.stopSpeaking()
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
    
    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            logger.error("WCSession activation failed: \(error.localizedDescription)")
        } else {
            logger.info("WCSession activated: \(activationState.rawValue)")
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        logger.info("WCSession became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        logger.info("WCSession deactivated")
        // Reactivate session if needed
        WCSession.default.activate()
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        handleReceivedData(applicationContext)
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleReceivedData(message)
    }
    
    private func handleReceivedData(_ data: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Update workout state
            if let isActive = data["isWorkoutActive"] as? Bool {
                let wasActive = self.isWorkoutActive
                self.isWorkoutActive = isActive
                
                if !isActive && wasActive {
                    // Workout just ended
                    self.heartRate = 0
                    self.distance = 0
                    self.lastUpdateTime = nil
                    self.isSpeaking = false
                    // Stop any ongoing speech
                    self.speechManager.stopSpeaking()
                    // Invalidate timer
                    self.metricsTimer?.invalidate()
                    self.metricsTimer = nil
                } else if isActive && !wasActive {
                    // Workout just started
                    self.setupMetricsTimer()
                }
            }
            
            // Update metrics only if workout is active
            if self.isWorkoutActive {
                if let hr = data["heartRate"] as? Double {
                    self.heartRate = hr
                }
                if let dist = data["distance"] as? Double {
                    self.distance = dist
                }
                if let timestamp = data["timestamp"] as? TimeInterval {
                    self.lastUpdateTime = Date(timeIntervalSince1970: timestamp)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    private func speakCurrentMetrics() {
        guard isWorkoutActive, !isSpeaking else { return }
        
        isSpeaking = true
        let text = String(format: "Current heart rate is %d bpm, distance covered is %.2f meters.", 
                         Int(heartRate), 
                         distance)
        speechManager.speak(text)
        
        // Reset speaking flag after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.isSpeaking = false
        }
    }
}
