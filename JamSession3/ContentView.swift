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
    // The client for communicating with the Python agent
    private let agentClient = AgentClient()

    // State to hold the last response from the agent for display
    @State private var agentResponse: String = "Waiting for command..."
    @State private var hasError: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Text("AI Music Looper")
                .font(.largeTitle)

            // A text view to display the agent's response
            Text(agentResponse)
                .font(.body)
                .padding()
                .frame(minWidth: 0, maxWidth: .infinity)
                .background(hasError ? Color.red.opacity(0.2) : Color.gray.opacity(0.2))
                .cornerRadius(8)


            // A button to send a "record" command
            Button("Send 'Record' Command") {
                sendCommand("record")
            }
            .buttonStyle(.borderedProminent)

            // A button to send a "stop" command
            Button("Send 'Stop' Command") {
                sendCommand("stop")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }

    /// Sends a command to the agent and updates the UI with the response.
    /// - Parameter command: The text of the command to send.
    private func sendCommand(_ command: String) {
        // Use a Task to perform the async network call
        Task {
            do {
                let response = try await agentClient.sendCommand(commandText: command)
                // Update the UI on the main thread
                await MainActor.run {
                    self.agentResponse = "Action: \(response.action), Status: \(response.status)"
                    self.hasError = false
                    print("Successfully received response: \(response)")
                }
            } catch {
                // Update the UI on the main thread
                await MainActor.run {
                    self.agentResponse = "Error: \(error.localizedDescription)"
                    self.hasError = true
                    print("Error sending command: \(error)")
                }
            }
        }
    }
}


#Preview {
    ContentView()
}
