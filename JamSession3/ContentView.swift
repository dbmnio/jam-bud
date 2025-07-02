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
    private let audioManager = AudioManager()
    private let agentClient = AgentClient()
    
    @State private var agentStatus: String = "Ready"
    @State private var isRecording = false
    @State private var trackCount = 0

    var body: some View {
        VStack(spacing: 20) {
            Text("AI Music Looper")
                .font(.largeTitle)
                .padding()

            Text(agentStatus)
                .font(.headline)
                .foregroundColor(.gray)
                .padding()

            HStack(spacing: 20) {
                Button(action: {
                    if isRecording {
                        sendCommand("stop")
                    } else {
                        sendCommand("record")
                    }
                }) {
                    Text(isRecording ? "Stop" : "Record")
                        .frame(width: 150)
                        .padding()
                        .background(isRecording ? Color.red : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding()

            Spacer()
        }
        .frame(minWidth: 450, minHeight: 300)
    }

    /// Sends a command to the agent and processes the returned action.
    private func sendCommand(_ command: String) {
        Task {
            do {
                let response = try await agentClient.sendCommand(commandText: command)
                await MainActor.run {
                    processAgentAction(response.action)
                }
            } catch {
                await MainActor.run {
                    agentStatus = "Error: \(error.localizedDescription)"
                }
            }
        }
    }

    /// Calls the appropriate AudioManager function based on the agent's action.
    private func processAgentAction(_ action: String) {
        switch action {
        case "start_recording":
            audioManager.startRecording()
            isRecording = true
            agentStatus = "Recording..."
        case "stop_recording":
            audioManager.stopRecordingAndCreateLoop(trackID: "track_\(trackCount + 1)")
            trackCount += 1
            isRecording = false
            agentStatus = "Looping \(trackCount) track(s)"
            // Automatically start playing all tracks after stopping a recording.
            audioManager.playAll()
        default:
            agentStatus = "Received unknown action: \(action)"
        }
    }
}

#Preview {
    ContentView()
}
