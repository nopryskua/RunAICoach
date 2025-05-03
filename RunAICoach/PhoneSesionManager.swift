//
//  PhoneSesionManager.swift
//  RunAICoach
//
//  Created by Nestor Oprysk on 5/3/25.
//

// TODO: Check if all imports required

import SwiftUI
import HealthKit
import Combine
import WatchConnectivity
import AVFoundation

class PhoneSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    func sessionDidBecomeInactive(_ session: WCSession) {
        // no-op
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        // no-op
    }
    
    static let shared = PhoneSessionManager()
    @Published private(set) var heartRate: Double = 0
    @Published private(set) var distance: Double = 0
    private var timer: Timer?
    private let speechManager = SpeechManager()

    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.speakCurrentMetrics()
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error { print("WCSession activation failed: \(error)") }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let hr = message["heartRate"] as? Double { heartRate = hr }
        if let dist = message["distance"] as? Double { distance = dist }
    }

    private func speakCurrentMetrics() {
        let text = String(format: "Current heart rate is %d bpm, distance covered is %.2f meters.", Int(heartRate), distance)
        speechManager.speak(text)
    }
}

class SpeechManager: NSObject {
    private let synthesizer = AVSpeechSynthesizer()
    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        // Ensure speech is synthesized on the main thread to avoid QoS inversion warnings
        DispatchQueue.main.async {
            self.synthesizer.speak(utterance)
        }
    }
}
