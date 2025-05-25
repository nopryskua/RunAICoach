//
//  SpeechManager.swift
//  RunAICoach
//
//  Created by Nestor Oprysk on 5/3/25.
//

import AVFoundation
import Foundation

class SpeechManager: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var utteranceQueue: [SpeechUtterance] = []
    private let openAIModel = "gpt-4o-mini-tts"
    private let openAIVoice = "ballad"
    private let useOpenAI: Bool
    private let openAIApiKey: String?
    private var currentOpenAICompletion: ((Bool) -> Void)?
    private var currentAudioPlayer: AVAudioPlayer?

    init(openAIApiKey: String? = nil) {
        self.openAIApiKey = openAIApiKey
        useOpenAI = openAIApiKey != nil
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // Configure for playback with mixing
            try session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers, .duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            // Log audio session configuration
            print("Audio session configured successfully")
            print("Category: \(session.category)")
            print("Mode: \(session.mode)")
            print("Options: \(session.categoryOptions)")
            print("Output volume: \(session.outputVolume)")
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    func speak(_ text: String, completion: ((Bool) -> Void)? = nil) {
        let utterance = SpeechUtterance(text: text, completion: completion)
        DispatchQueue.main.async {
            self.utteranceQueue.append(utterance)
            self.trySpeakingNext()
        }
    }

    func stopSpeaking() {
        DispatchQueue.main.async {
            self.synthesizer.stopSpeaking(at: .immediate)
            self.currentAudioPlayer?.stop()
            self.currentAudioPlayer = nil
            self.utteranceQueue.removeAll()
        }
    }

    private func trySpeakingNext() {
        guard !synthesizer.isSpeaking, currentAudioPlayer == nil, let next = utteranceQueue.first else { return }
        utteranceQueue.removeFirst()

        if useOpenAI {
            speakWithOpenAI(next.text) { [weak self] success in
                if !success {
                    // Fallback to AVSpeechSynthesizer if OpenAI fails
                    self?.speakWithAVSpeechSynthesizer(next.text)
                }
                next.completion?(success)
            }
        } else {
            speakWithAVSpeechSynthesizer(next.text)
            next.completion?(true)
        }
    }

    private func speakWithAVSpeechSynthesizer(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = 1.0
        utterance.pitchMultiplier = 1.0

        // Log speech attempt
        print("Speaking with AVSpeechSynthesizer: \(text)")

        synthesizer.speak(utterance)
    }

    private func speakWithOpenAI(_ text: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/audio/speech"),
              let apiKey = openAIApiKey
        else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": openAIModel,
            "voice": openAIVoice,
            "input": text,
            "instructions": "Use a soothing, calm tone with gentle pacing, like a mindfulness coach guiding a relaxed but focused run. Emphasize breathing and presence.",
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        print("Sending request to OpenAI TTS API...")
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else {
                completion(false)
                return
            }

            if let error = error {
                print("OpenAI API error: \(error)")
                completion(false)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response from OpenAI API")
                completion(false)
                return
            }

            if httpResponse.statusCode != 200 {
                print("OpenAI API returned status code: \(httpResponse.statusCode)")
                completion(false)
                return
            }

            guard let data = data else {
                print("No data received from OpenAI API")
                completion(false)
                return
            }

            print("Received audio data from OpenAI API, size: \(data.count) bytes")

            // Play the audio data
            do {
                // Stop any existing audio
                self.currentAudioPlayer?.stop()

                // Create and configure new audio player
                let audioPlayer = try AVAudioPlayer(data: data)
                audioPlayer.delegate = self
                audioPlayer.volume = 1.0
                audioPlayer.prepareToPlay()

                // Store the audio player and completion handler
                self.currentAudioPlayer = audioPlayer
                self.currentOpenAICompletion = completion

                // Play the audio
                let success = audioPlayer.play()
                print("Started playing OpenAI audio: \(success)")

                if !success {
                    print("Failed to start playing audio")
                    self.currentAudioPlayer = nil
                    completion(false)
                } else {
                    // Call completion immediately since we've started playing
                    // The audio will continue playing in the background
                    completion(true)
                }
            } catch {
                print("Failed to create audio player: \(error)")
                completion(false)
            }
        }

        task.resume()
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_: AVAudioPlayer, successfully flag: Bool) {
        print("Audio player finished playing, success: \(flag)")
        currentAudioPlayer = nil
        currentOpenAICompletion = nil
        trySpeakingNext()
    }

    func audioPlayerDecodeErrorDidOccur(_: AVAudioPlayer, error: Error?) {
        print("Audio player decode error: \(error?.localizedDescription ?? "unknown error")")
        currentAudioPlayer = nil
        currentOpenAICompletion = nil
        trySpeakingNext()
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_: AVSpeechSynthesizer, didFinish _: AVSpeechUtterance) {
        trySpeakingNext()
    }
}

// MARK: - Supporting Types

private struct SpeechUtterance {
    let text: String
    let completion: ((Bool) -> Void)?
}
