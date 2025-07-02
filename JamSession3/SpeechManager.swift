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
    
    // Speech Recognition
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // Audio Engine for Speech
    private let audioEngine = AVAudioEngine()
    
    // Speech Synthesis
    private let speechSynthesizer = AVSpeechSynthesizer()

    override init() {
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

    /// Starts the audio engine and begins transcribing speech.
    func startTranscribing() {
        guard !isRecording else { return }
        
        // Cancel the previous task if it's running.
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("audioSession properties weren't set because of an error.")
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
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
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.isRecording = false
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            print("audioEngine couldn't start because of an error.")
        }
        
        isRecording = true
        transcribedText = ""
    }

    /// Stops transcription and the audio engine.
    func stopTranscribing() {
        guard isRecording else { return }
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isRecording = false
    }
    
    /// Speaks the given text using the system's voice.
    /// - Parameter text: The string to be spoken.
    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtterance.defaultSpeechRate
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