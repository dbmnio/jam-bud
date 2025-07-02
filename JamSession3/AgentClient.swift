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

/**
 * The response structure from the agent's /command endpoint.
 * All fields are optional because the agent will only return the fields
 * relevant to the specific action it wants the app to take.
 */
struct AgentResponse: Codable {
    let action: String?
    let speak: String?
    let track_id: String?
    let volume: Float?
}

/// A request structure for sending a command to the agent.
struct CommandRequest: Codable {
    let text: String
}

/// A client to send commands to the Python agent and receive actions.
class AgentClient: ObservableObject {
    private let agentURL = URL(string: "http://127.0.0.1:8000/command")!

    /// Sends a command to the agent's backend and returns the planned action.
    /// - Parameter command: The command string to send (e.g., "record").
    /// - Parameter completion: A closure that is called with the agent's response.
    func postCommand(command: String) async throws -> AgentResponse {
        var request = URLRequest(url: agentURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let commandRequest = CommandRequest(text: command)
        let requestBody = try JSONEncoder().encode(commandRequest)
        request.httpBody = requestBody

        print("Sending command: '\(command)' to agent...")
        
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let agentResponse = try JSONDecoder().decode(AgentResponse.self, from: data)
        print("Received response: \(agentResponse) from agent.")
        return agentResponse
    }
} 