//
//  AgentClient.swift
//  JamSession3
//
//  Created by AI Assistant on 6/14/24.
//
//  This file defines the network client responsible for communicating
//  with the Python-based AI agent server.
//

import Foundation

/// Defines the structure for the JSON response from the agent.
/// Must be `Codable` to be easily decoded from the network response.
struct AgentResponse: Codable {
    let action: String
    let status: String
}

/// Defines the structure for the JSON request sent to the agent.
/// Must be `Codable` to be easily encoded for the network request.
struct CommandRequest: Codable {
    let text: String
}

/// An enumeration to represent potential networking errors.
enum AgentClientError: Error {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case encodingError(Error)
}

/// The `AgentClient` class handles all communication with the Python backend.
/// It sends commands and receives actions to be executed by the audio engine.
class AgentClient {

    private let serverURL: URL?

    init(urlString: String = "http://127.0.0.1:8000/command") {
        self.serverURL = URL(string: urlString)
    }

    /// Sends a text command to the Python agent server.
    /// - Parameter commandText: The string command to be sent (e.g., "record").
    /// - Returns: An `AgentResponse` object decoded from the server's JSON response.
    /// - Throws: An `AgentClientError` if the URL is invalid, or if there is a
    ///           networking, encoding, or decoding error.
    func sendCommand(commandText: String) async throws -> AgentResponse {
        guard let url = serverURL else {
            throw AgentClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let commandRequest = CommandRequest(text: commandText)
        do {
            request.httpBody = try JSONEncoder().encode(commandRequest)
        } catch {
            throw AgentClientError.encodingError(error)
        }
        
        let (data, _) = try await URLSession.shared.data(for: request)

        do {
            let agentResponse = try JSONDecoder().decode(AgentResponse.self, from: data)
            return agentResponse
        } catch {
            throw AgentClientError.decodingError(error)
        }
    }
} 