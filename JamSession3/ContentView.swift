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
    @StateObject private var speechManager = SpeechManager()
    @StateObject private var audioManager = AudioManager()
    @StateObject private var agentClient = AgentClient()

    @State private var agentStatus: String = "Ready"
    @State private var trackCount = 0

    var body: some View {
        VStack(spacing: 20) {
            Text("AI Music Looper")
                .font(.largeTitle)
                .padding()

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

            // The main interaction button
            Button(action: {
                if speechManager.isRecording {
                    speechManager.stopTranscribing()
                    // After stopping, immediately send the command
                    if !speechManager.transcribedText.isEmpty {
                        postCommand(speechManager.transcribedText)
                    }
                } else {
                    speechManager.startTranscribing()
                }
            }) {
                Text(speechManager.isRecording ? "Stop Listening" : "Push to Talk")
                    .frame(width: 200, height: 50)
                    .background(speechManager.isRecording ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
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
                agentStatus = "Recording..."
            case "stop_recording_and_create_loop":
                guard let trackID = response.track_id else {
                    agentStatus = "Error: stop_recording action missing track_id"
                    return
                }
                audioManager.stopRecordingAndCreateLoop(trackID: trackID)
                trackCount += 1
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
            default:
                agentStatus = "Received unknown action: \(action)"
            }
        }
    }
}

#Preview {
    ContentView()
}
