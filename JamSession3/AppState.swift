//
//  AppState.swift
//  JamSession3
//
//  Created by I.T. on 2024-07-17.
//
//  This file defines the AppState class, which serves as the single source
//  of truth for the application's state and orchestrates actions between
//  the UI, the AgentClient, and the audio/speech managers.
//

import Foundation
import SwiftUI

@MainActor
class AppState: ObservableObject {
    @Published var agentState: AgentState?
    
    private let agentClient = AgentClient()
    let audioManager: AudioManager
    let speechManager: SpeechManager

    init(audioManager: AudioManager, speechManager: SpeechManager) {
        self.audioManager = audioManager
        self.speechManager = speechManager
        // Initialize with a default, empty state.
        // The onAppear call in ContentView will sync it with the backend's state.
        self.agentState = AgentState(
            history_node_id: nil,
            tracks: [],
            next_track_id: 0
        )
    }

    func sendCommand(text: String) async {
        do {
            let response = try await agentClient.postCommand(
                command: text,
                historyNodeID: agentState?.history_node_id
            )
            handleResponse(response)
        } catch {
            print("Error sending command: \(error)")
            speechManager.speak("I'm sorry, I encountered an error trying to connect to my brain.")
        }
    }

    private func handleResponse(_ response: AgentResponse) {
        // Update the history node ID after every successful command.
        if let newHistoryNodeID = response.history_node_id {
            agentState?.history_node_id = newHistoryNodeID
        }

        if let textToSpeak = response.speak {
            speechManager.speak(textToSpeak)
        }
        
        guard let action = response.action else {
            print("No action received from agent.")
            return
        }
        
        switch action {
        case "start_recording":
            audioManager.startRecording()
        case "stop_recording_and_create_loop":
            // The agent has created the track in its state. We now create the
            // corresponding audio nodes and add the track to our local state
            // to keep the UI in sync.
            if let newTrack = response.track {
                audioManager.stopRecordingAndCreateLoop(trackID: newTrack.id)
                agentState?.tracks.append(newTrack)
            }
        case "add_new_track":
            // This will require more work to load from a file path.
            // For now, we just acknowledge the action.
            if let track = response.track {
                 print("Agent requested to add new track: \(track.name)")
            }
        case "load_state":
            if let newState = response.state {
                self.agentState = newState
                // This is a major action. We need to tell the audio manager
                // to rebuild its entire state from this new data.
                // (To be implemented)
                print("Agent requested to load a new state with \(newState.tracks.count) tracks.")
            }
        case "set_volume":
            if let trackID = response.track_id, let volume = response.volume {
                audioManager.setVolume(forTrack: trackID, volume: volume)
            }
        case "set_reverb":
            if let trackID = response.track_id, let value = response.value {
                audioManager.setReverb(for: trackID, to: value)
            }
        case "set_delay":
            if let trackID = response.track_id, let value = response.value {
                audioManager.setDelay(for: trackID, to: value)
            }
        case "mute_track":
            if let trackID = response.track_id {
                audioManager.muteTrack(trackID: trackID)
            }
        case "unmute_track":
            if let trackID = response.track_id, let volume = response.volume {
                audioManager.unmuteTrack(trackID: trackID, volume: volume)
            }
        default:
            print("Received unknown action: \(action)")
        }
    }
} 