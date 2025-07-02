//
//  ContentView.swift
//  JamSession3
//
//  Created by David Matthew on 7/1/25.
//
//  This is the main view of the application. It provides a simple
//  interface for sending commands to the AI agent.
//

import SwiftUI

struct ContentView: View {
    // State Objects for managing app logic
    @StateObject private var audioManager = AudioManager()
    // SpeechManager now depends on AudioManager, so we initialize it in the view's init.
    @StateObject private var speechManager: SpeechManager
    @StateObject private var agentClient = AgentClient()

    @State private var agentStatus: String = "Ready"
    @State private var trackCount = 0
    @State private var isRecordingLoop = false

    init() {
        // Create the AudioManager first
        let audioManager = AudioManager()
        // Now create the SpeechManager and pass the AudioManager to it
        _speechManager = StateObject(wrappedValue: SpeechManager(audioManager: audioManager))
        // Assign the same AudioManager instance to the property
        _audioManager = StateObject(wrappedValue: audioManager)
    }

    var body: some View {
        VStack(spacing: 15) {
            Text("AI Music Looper")
                .font(.largeTitle)
                .padding(.bottom, 5)

            // Display for agent status and transcribed text
            VStack {
                Text(agentStatus)
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text(speechManager.transcribedText)
                    .font(.body)
                    .foregroundColor(.primary)
                    .frame(minHeight: 40)
            }
            .padding()

            // Main interaction buttons
            HStack(spacing: 20) {
                // Button 1: Record/Stop Toggle
                Button(action: {
                    let command = isRecordingLoop ? "stop" : "record"
                    postCommand(command)
                }) {
                    Text(isRecordingLoop ? "Stop" : "Record")
                        .frame(width: 150, height: 50)
                        .background(isRecordingLoop ? Color.red : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                // Button 2: Push to Talk
                Button(action: {
                    if speechManager.isRecording {
                        speechManager.stopTranscribing()
                        if !speechManager.transcribedText.isEmpty {
                            postCommand(speechManager.transcribedText)
                        }
                    } else {
                        speechManager.startTranscribing()
                    }
                }) {
                    Text(speechManager.isRecording ? "Listening..." : "Push to Talk")
                        .frame(width: 150, height: 50)
                        .background(speechManager.isRecording ? Color.purple : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding()

            Spacer()
        }
        .frame(minWidth: 450, minHeight: 300)
        .onAppear(perform: speechManager.requestPermission)
    }

    /// Sends a transcribed command to the agent and handles the response.
    private func postCommand(_ command: String) {
        Task {
            do {
                let response = try await agentClient.postCommand(command: command)
                await MainActor.run {
                    handle(response: response)
                }
            } catch {
                await MainActor.run {
                    agentStatus = "Error: \(error.localizedDescription)"
                }
            }
        }
    }

    /// Processes the agent's response and calls the appropriate managers.
    private func handle(response: AgentResponse) {
        // Handle spoken feedback first
        if let textToSpeak = response.speak {
            speechManager.speak(textToSpeak)
            agentStatus = textToSpeak
        }

        // Handle audio engine actions
        if let action = response.action {
            switch action {
            case "start_recording":
                audioManager.startRecording()
                isRecordingLoop = true
                agentStatus = "Recording..."
            case "stop_recording_and_create_loop":
                guard let trackID = response.track_id else {
                    agentStatus = "Error: stop_recording action missing track_id"
                    return
                }
                audioManager.stopRecordingAndCreateLoop(trackID: trackID)
                trackCount += 1
                isRecordingLoop = false
                agentStatus = "Looping \(trackCount) track(s)"
                // Automatically start playing all tracks after creating a new one.
                audioManager.playAll()
            case "set_volume":
                guard let trackID = response.track_id, let volume = response.volume else {
                    agentStatus = "Error: set_volume action missing parameters"
                    return
                }
                audioManager.setVolume(forTrack: trackID, volume: volume)
                agentStatus = "Set volume for \(trackID) to \(volume)"
            case "mute_track":
                guard let trackID = response.track_id else {
                    agentStatus = "Error: mute_track action missing track_id"
                    return
                }
                audioManager.muteTrack(trackID: trackID)
                agentStatus = "Muted track \(trackID)"
            case "unmute_track":
                guard let trackID = response.track_id, let volume = response.volume else {
                    agentStatus = "Error: unmute_track action missing parameters"
                    return
                }
                audioManager.unmuteTrack(trackID: trackID, volume: volume)
                agentStatus = "Unmuted track \(trackID)"
            default:
                agentStatus = "Received unknown action: \(action)"
            }
        }
    }
}

#Preview {
    ContentView()
}
