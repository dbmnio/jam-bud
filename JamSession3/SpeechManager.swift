//
//  SpeechManager.swift
//  JamSession3
//
//  Created by [Your Name] on [Date].
//
//  This file defines the SpeechManager class, which is responsible for handling
//  all speech-to-text (STT) and text-to-speech (TTS) functionalities for the app.
//  It uses Apple's native SFSpeechRecognizer for transcription and AVSpeechSynthesizer
//  for generating spoken feedback from the AI agent.
//

import Foundation
import Speech
import AVFoundation

class SpeechManager: NSObject, ObservableObject {
    @Published var transcribedText: String = ""
    @Published var isRecording: Bool = false
    
    // Dependencies
    private var audioManager: AudioManager
    
    // Speech Recognition
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // Speech Synthesis
    private let speechSynthesizer = AVSpeechSynthesizer()

    /// Initializes the SpeechManager.
    /// - Parameter audioManager: The shared AudioManager instance.
    init(audioManager: AudioManager) {
        self.audioManager = audioManager
        super.init()
        speechRecognizer.delegate = self
    }

    /// Requests user authorization for speech recognition.
    func requestPermission() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    print("Speech recognition authorized.")
                case .denied, .restricted, .notDetermined:
                    print("Speech recognition not authorized.")
                @unknown default:
                    fatalError("Unknown authorization status.")
                }
            }
        }
    }

    /// Starts transcribing speech by consuming audio from the AudioManager.
    func startTranscribing() {
        guard !isRecording else { return }
        
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                self.transcribedText = result.bestTranscription.formattedString
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.stopTranscribing() // Ensure we stop if the task ends
            }
        }
        
        // Register as a consumer with the AudioManager
        audioManager.addAudioBufferConsumer(self.handleAudioBuffer, withKey: "speechRecognizer")

        isRecording = true
        transcribedText = ""
    }
    
    /// Receives an audio buffer from the AudioManager and appends it to the recognition request.
    /// - Parameter buffer: The audio buffer from the microphone input.
    private func handleAudioBuffer(buffer: AVAudioPCMBuffer) {
        self.recognitionRequest?.append(buffer)
    }

    /// Stops transcription.
    func stopTranscribing() {
        guard isRecording else { return }
        
        // Unregister from the AudioManager
        audioManager.removeAudioBufferConsumer(withKey: "speechRecognizer")
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel() // Use cancel to ensure task is fully torn down
        
        self.recognitionRequest = nil
        self.recognitionTask = nil
        self.isRecording = false
    }
    
    /// Speaks the given text using the system's voice.
    /// - Parameter text: The string to be spoken.
    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        speechSynthesizer.speak(utterance)
    }
}

extension SpeechManager: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            print("Speech recognizer is available.")
        } else {
            print("Speech recognizer is not available.")
        }
    }
} 