//
//  SpeechManager.swift
//  RunAICoach
//
//  Created by Nestor Oprysk on 5/3/25.
//

import AVFoundation

class SpeechManager: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var utteranceQueue: [AVSpeechUtterance] = []

    override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, options: [.mixWithOthers, .interruptSpokenAudioAndMixWithOthers])
            try session.setMode(.spokenAudio)
            try session.setActive(true, options: [])
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        DispatchQueue.main.async {
            self.utteranceQueue.append(utterance)
            self.trySpeakingNext()
        }
    }
    
    func stopSpeaking() {
        DispatchQueue.main.async {
            self.synthesizer.stopSpeaking(at: .immediate)
            self.utteranceQueue.removeAll()
        }
    }

    private func trySpeakingNext() {
        guard !synthesizer.isSpeaking, let next = utteranceQueue.first else { return }
        utteranceQueue.removeFirst()
        synthesizer.speak(next)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        trySpeakingNext()
    }
}
