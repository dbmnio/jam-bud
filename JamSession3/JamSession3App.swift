//
//  JamSession3App.swift
//  JamSession3
//
//  Created by David Matthew on 7/1/25.
//

import SwiftUI

@main
struct JamSession3App: App {
    // Create instances of our managers.
    // The AudioManager is created first, then passed into the SpeechManager
    // to ensure a single, shared audio source.
    private static let audioManager = AudioManager()
    private static let speechManager = SpeechManager(audioManager: audioManager)
    
    // The AppState holds the application's state and orchestrates actions.
    @StateObject private var appState: AppState

    init() {
        // We need to initialize AppState here so it can get references
        // to our other singleton managers that are properties of this struct.
        _appState = StateObject(wrappedValue: AppState(audioManager: Self.audioManager, speechManager: Self.speechManager))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
