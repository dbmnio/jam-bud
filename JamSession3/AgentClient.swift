//
//  AgentClient.swift
//  JamSession3
//
//  Created by I.T. on 2024-07-15.
//
//  This file defines the AgentClient class, which is responsible for
//  communicating with the Python-based AI agent backend.
//

import Foundation

// MARK: - Data Structures for Agent Communication

/// The complete state of the session, mirroring the Python `AgentState`.
struct AgentState: Codable {
    var history_node_id: String?
    var tracks: [Track]
    var next_track_id: Int
}

/// Represents a single audio track, mirroring the Python `Track` TypedDict.
struct Track: Codable, Identifiable {
    var id: String
    var name: String
    var volume: Float
    var is_playing: Bool
    var path: String?
    var reverb: Float?
    var delay: Float?
}

/**
 * The response structure from the agent's /command endpoint.
 * This structure is flexible to handle various actions the agent might request.
 */
struct AgentResponse: Codable {
    let action: String?
    let speak: String?
    let track_id: String?
    let volume: Float?
    let value: Float? // Generic value for effects like reverb/delay
    let track: Track? // For the 'add_new_track' action
    let state: AgentState? // For the 'load_state' action
    let history_node_id: String?
}

/// A request structure for sending a command to the agent.
struct CommandRequest: Codable {
    let text: String
    let history_node_id: String?
}

/// A client to send commands to the Python agent and receive actions.
class AgentClient: ObservableObject {
    private let agentURL = URL(string: "http://127.0.0.1:8000/command")!

    /// Sends a command to the agent's backend and returns the planned action.
    /// - Parameter command: The command string to send (e.g., "record").
    /// - Parameter historyNodeID: The ID of the current state node in the history tree.
    func postCommand(command: String, historyNodeID: String?) async throws -> AgentResponse {
        var request = URLRequest(url: agentURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let commandRequest = CommandRequest(text: command, history_node_id: historyNodeID)
        let requestBody = try JSONEncoder().encode(commandRequest)
        request.httpBody = requestBody

        print("Sending command: '\(command)' with node: \(historyNodeID ?? "root")")
        
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            // Try to decode an error message from the body for better debugging
            if let errorBody = String(data: data, encoding: .utf8) {
                print("Server error: \(errorBody)")
            }
            throw URLError(.badServerResponse)
        }
        
        let agentResponse = try JSONDecoder().decode(AgentResponse.self, from: data)
        print("Received response: \(agentResponse)")
        return agentResponse
    }
} 