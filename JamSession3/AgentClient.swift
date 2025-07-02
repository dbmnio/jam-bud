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

/// The response structure from the agent's /command endpoint.
struct AgentResponse: Codable {
    let action: String
    let status: String
}

/// A request structure for sending a command to the agent.
struct CommandRequest: Codable {
    let text: String
}

/// A client to send commands to the Python agent and receive actions.
class AgentClient {
    private let agentURL = URL(string: "http://127.0.0.1:8000/command")!

    /// Sends a command to the agent's backend.
    /// - Parameter commandText: The command string to send (e.g., "record").
    /// - Returns: An `AgentResponse` containing the action to be taken.
    /// - Throws: An error if the network request fails or decoding fails.
    func sendCommand(commandText: String) async throws -> AgentResponse {
        var request = URLRequest(url: agentURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let command = CommandRequest(text: commandText)
        let requestBody = try JSONEncoder().encode(command)
        request.httpBody = requestBody

        print("Sending command: '\(commandText)' to agent...")
        
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let agentResponse = try JSONDecoder().decode(AgentResponse.self, from: data)
        print("Received action: '\(agentResponse.action)' from agent.")
        return agentResponse
    }
} 