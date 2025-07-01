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
    @State private var isRecording = false
    @State private var trackCount = 0

    var body: some View {
        VStack(spacing: 20) {
            Text("AI Music Looper")
                .font(.largeTitle)
                .padding()

            Text("Phase 1: Audio Engine Test")
                .font(.headline)
                .foregroundColor(.gray)

            HStack(spacing: 20) {
                Button(action: {
                    if isRecording {
                        // A unique ID for the track, can be more sophisticated later
                        audioManager.stopRecordingAndCreateLoop(trackID: "track_\(trackCount + 1)")
                        trackCount += 1
                    } else {
                        audioManager.startRecording()
                    }
                    isRecording.toggle()
                }) {
                    Text(isRecording ? "Stop Recording" : "Start Recording")
                        .frame(width: 150)
                        .padding()
                        .background(isRecording ? Color.red : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                VStack(spacing: 10) {
                    Button(action: {
                        audioManager.playAll()
                    }) {
                        Text("Play All")
                            .frame(width: 100)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }

                    Button(action: {
                        audioManager.stopAll()
                    }) {
                        Text("Stop All")
                            .frame(width: 100)
                            .padding()
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            }
            .padding()

            Spacer()
        }
        .frame(minWidth: 450, minHeight: 300)
    }
}

#Preview {
    ContentView()
}
