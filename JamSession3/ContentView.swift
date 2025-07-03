//
//  ContentView.swift
//  JamSession3
//
//  Created by David Matthew on 7/1/25.
//
//  This is the main view of the application. It provides the user
//  interface for interacting with the AI music looper.
//

import SwiftUI

struct ContentView: View {
    // The AppState is the single source of truth for our UI.
    @EnvironmentObject var appState: AppState
    
    // Local state for the view
    @State private var isRecordingLoop = false

    var body: some View {
        VStack(spacing: 15) {
            Text("AI Music Looper")
                .font(.largeTitle)
                .padding(.bottom, 5)
            
            // A simple status indicator for listening
            if appState.speechManager.isRecording {
                Text("Listening...")
                    .foregroundColor(.secondary)
            }

            // List of Tracks
            List {
                if let tracks = appState.agentState?.tracks, !tracks.isEmpty {
                    ForEach(tracks) { track in
                        TrackView(track: track)
                    }
                } else {
                    Text("No tracks yet. Record something!")
                        .foregroundColor(.secondary)
                }
            }
            .listStyle(PlainListStyle())
            .frame(minHeight: 150)

            // Main interaction buttons
            HStack(spacing: 20) {
                // Button 1: Record/Stop Toggle
                Button(action: {
                    isRecordingLoop.toggle()
                    let command = isRecordingLoop ? "record" : "stop"
                    Task {
                        await appState.sendCommand(text: command)
                    }
                }) {
                    Text(isRecordingLoop ? "Stop Recording" : "Start Recording")
                        .frame(width: 150, height: 50)
                        .background(isRecordingLoop ? Color.red : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                // Button 2: Push to Talk for voice commands
                Button(action: {
                    if appState.speechManager.isRecording {
                        appState.speechManager.stopTranscribing()
                        if !appState.speechManager.transcribedText.isEmpty {
                            Task {
                                await appState.sendCommand(text: appState.speechManager.transcribedText)
                            }
                        }
                    } else {
                        appState.speechManager.startTranscribing()
                    }
                }) {
                    Text(appState.speechManager.isRecording ? "Finish Talking" : "Push to Talk")
                        .frame(width: 150, height: 50)
                        .background(appState.speechManager.isRecording ? Color.purple : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding()

            Spacer()
        }
        .frame(minWidth: 450, minHeight: 350)
        .padding()
        .onAppear {
            // Send an empty command on appear to get the initial state from the agent
            Task {
                await appState.sendCommand(text: "")
            }
        }
    }
}

/// A view that represents a single track in the list.
struct TrackView: View {
    let track: Track

    var body: some View {
        HStack {
            Image(systemName: track.is_playing ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .foregroundColor(track.is_playing ? .green : .red)
            Text(track.name)
                .font(.headline)
            Spacer()
            VStack(alignment: .trailing) {
                Text("Volume: \(Int(track.volume * 100))%")
                if let path = track.path {
                    Text(path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        // To make the preview work, we need to create mock/stub versions
        // of our managers and AppState.
        let audioManager = AudioManager()
        let speechManager = SpeechManager()
        let appState = AppState(audioManager: audioManager, speechManager: speechManager)
        
        // Populate with some mock data for the preview
        appState.agentState = AgentState(
            history_node_id: "preview-node",
            tracks: [
                Track(id: "track_0", name: "Guitar Loop", volume: 0.8, is_playing: true, path: "loop_1.mp3"),
                Track(id: "track_1", name: "AI Drums", volume: 1.0, is_playing: true, path: "gen_1.mp3"),
                Track(id: "track_2", name: "Muted Vocals", volume: 0.6, is_playing: false, path: "loop_2.mp3")
            ],
            next_track_id: 3
        )

        return ContentView()
            .environmentObject(appState)
    }
}
