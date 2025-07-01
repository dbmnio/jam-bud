# Implementation Plan: Phase 1, Task 1 - Native Audio Engine (Swift)

This document provides a step-by-step plan for implementing the core audio functionality of the AI Music Looper application as outlined in `implementation-overview.md`. This work will be done within the `JamSession3` Xcode project.

## 1. Create a Dedicated Audio Manager

To maintain a clean and modular architecture, all `AVAudioEngine` logic should be encapsulated within its own class.

**Action:**
- Create a new Swift file: `JamSession3/AudioManager.swift`.
- Define a class named `AudioManager`. This class will be responsible for all audio-related tasks.

```swift
// JamSession3/AudioManager.swift

import Foundation
import AVFoundation

class AudioManager {
    // All audio engine code will go here.
}
```

## 2. Initialize the Audio Engine and Graph

The foundation of our audio system is the `AVAudioEngine` and its node graph. We will set up an engine with a main mixer to combine all our audio tracks.

**Action:**
- In `AudioManager.swift`, add properties for the `AVAudioEngine` and the main `AVAudioMixerNode`.
- Create an initializer (`init`) that sets up the engine, attaches the mixer, and connects it to the default output.
- It is critical to handle potential errors during setup by using `do-try-catch` blocks.

```swift
// ... inside AudioManager class

private var engine = AVAudioEngine()
private var mainMixer = AVAudioMixerNode()
private var playerNodes = [AVAudioPlayerNode]()
private var isRecording = false
private var recordingOutputFileURL: URL?

init() {
    setupAudioSession()
    setupEngine()
}

private func setupAudioSession() {
    let session = AVAudioSession.sharedInstance()
    do {
        try session.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
        try session.setActive(true)
    } catch {
        print("Failed to set up audio session: \(error)")
    }
}

private func setupEngine() {
    engine.attach(mainMixer)
    engine.connect(mainMixer, to: engine.outputNode, format: nil)
    
    do {
        try engine.start()
    } catch {
        print("Failed to start audio engine: \(error)")
    }
}
```

## 3. Implement Recording Logic

Recording requires tapping into the engine's input node and writing the incoming audio data to a file.

**Action:**
- Implement the `startRecording()` method.
- This method should get the input node, determine a temporary file path for the recording, and install a tap on the input node.
- The tap's block will receive audio buffers and write them to an `AVAudioFile`.

```swift
// ... inside AudioManager class

func startRecording() {
    guard !isRecording else {
        print("Already recording.")
        return
    }

    let inputNode = engine.inputNode
    let format = inputNode.outputFormat(forBus: 0)
    let tempDir = FileManager.default.temporaryDirectory
    recordingOutputFileURL = tempDir.appendingPathComponent("loop_\(Date().timeIntervalSince1970).caf")

    do {
        let outputFile = try AVAudioFile(forWriting: recordingOutputFileURL!, settings: format.settings)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { (buffer, when) in
            do {
                try outputFile.write(from: buffer)
            } catch {
                print("Error writing buffer to file: \(error)")
            }
        }
        isRecording = true
        print("Started recording.")
    } catch {
        print("Failed to start recording: \(error)")
    }
}
```

## 4. Implement Loop Creation and Playback

This is the core of the looper. When recording stops, we create a new player node, load the recorded file, and schedule it for looped playback.

**Action:**
- Implement the `stopRecordingAndCreateLoop(trackID: String)` method.
- This method will remove the recording tap, then create, attach, and connect a new `AVAudioPlayerNode` to the `mainMixer`.
- It will then load the audio from the temporary file into an `AVAudioPCMBuffer` and schedule it to play on a loop.

```swift
// ... inside AudioManager class

func stopRecordingAndCreateLoop(trackID: String) {
    guard isRecording else { return }

    engine.inputNode.removeTap(onBus: 0)
    isRecording = false
    print("Stopped recording.")
    
    guard let url = recordingOutputFileURL else { return }
    
    do {
        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(audioFile.length)) else {
             print("Could not create buffer")
             return
        }
        try audioFile.read(into: buffer)

        let playerNode = AVAudioPlayerNode()
        playerNodes.append(playerNode)
        
        engine.attach(playerNode)
        engine.connect(playerNode, to: mainMixer, format: format)

        playerNode.scheduleBuffer(buffer, at: nil, options: .loops)
        
        print("Loop created for trackID: \(trackID)")
    } catch {
        print("Failed to create loop: \(error)")
    }
}
```

## 5. Implement Transport Controls

Provide simple methods to control the overall playback of all active loops.

**Action:**
- Implement `playAll()` and `stopAll()` methods.
- These will iterate over the `playerNodes` array and call `play()` or `stop()` on each node.

```swift
// ... inside AudioManager class

func playAll() {
    if engine.isRunning {
        for player in playerNodes {
            player.play()
        }
        print("Playing all loops.")
    } else {
        print("Engine not running.")
    }
}

func stopAll() {
    for player in playerNodes {
        player.stop()
    }
    print("Stopped all loops.")
}

```

## 6. Integration with `AgentClient`

Once the `AudioManager` is complete, it needs to be instantiated and controlled from a higher-level component that communicates with the Python backend. For now, we can plan to call these methods from `ContentView.swift` for testing, and later from a dedicated `AgentClient`.

**Next Steps (for Task 2):**
- An instance of `AudioManager` will be created.
- The component responsible for network communication will hold a reference to the `AudioManager` instance.
- When a command like `{"action": "start_recording"}` is received from the Python server, the corresponding `AudioManager` method (`startRecording()`) will be called.