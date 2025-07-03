//
//  AudioManager.swift
//  JamSession3
//
//  Created by I.T. on 2024-07-15.
//
//  This file contains the AudioManager class, which encapsulates all the
//  logic for handling real-time audio processing using Apple's AVAudioEngine.
//  It is responsible for setting up the audio engine, recording from the microphone,
//  creating looped audio players, and controlling playback.
//

import Foundation
import AVFoundation

/**
 * Manages all audio-related operations for the application.
 *
 * This class sets up and controls an AVAudioEngine instance to handle
 * real-time audio recording and playback of multiple overlapping loops.
 * It provides methods to start and stop recording, create new loop players,
 * and control the transport (play/stop) of all active loops.
 */
class AudioManager: ObservableObject {

    // Define a type for a closure that consumes audio buffers.
    typealias AudioBufferConsumer = (AVAudioPCMBuffer) -> Void
    
    private struct TrackNodes {
        var player: AVAudioPlayerNode
        var reverb: AVAudioUnitReverb
        var delay: AVAudioUnitDelay
    }
    
    private var engine = AVAudioEngine()
    private var mainMixer = AVAudioMixerNode()
    private var tracks = [String: TrackNodes]()
    private var isRecording = false
    private var recordingOutputFileURL: URL?
    private var outputFile: AVAudioFile?
    
    // A dictionary to hold multiple consumers of the live audio stream.
    private var bufferConsumers = [String: AudioBufferConsumer]()

    /**
     * Initializes the AudioManager.
     *
     * Sets up the shared audio session for recording and playback,
     * then configures and starts the AVAudioEngine.
     */
    init() {
        // Asynchronously request microphone permission and setup the engine on success.
        requestMicrophonePermission { [weak self] granted in
            guard let self = self else { return }
            if granted {
                DispatchQueue.main.async {
                    self.setupEngine()
                }
            } else {
                print("Microphone permission was not granted. Audio engine will not be set up.")
            }
        }
    }

    deinit {
        // Ensure the engine is stopped when the manager is deallocated.
        engine.stop()
    }

    /**
     * Requests permission to access the microphone.
     *
     * This method checks the current authorization status and, if undetermined,
     * prompts the user for permission. It uses a completion handler to report success.
     * @param completion A closure that returns true if access is granted, otherwise false.
     */
    private func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: // The user has previously granted access to the microphone.
            print("Microphone access previously granted.")
            completion(true)
        case .notDetermined: // The user has not yet been asked for microphone access.
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if granted {
                    print("Microphone access has been granted.")
                } else {
                    print("Microphone access has been denied.")
                }
                completion(granted)
            }
        case .denied: // The user has previously denied access.
            print("Microphone access was previously denied.")
            completion(false)
        case .restricted: // The user can't grant access due to restrictions.
            print("Microphone access is restricted.")
            completion(false)
        @unknown default:
            print("Unknown authorization status for microphone.")
            completion(false)
        }
    }

    /**
     * Configures the AVAudioEngine and its audio graph.
     *
     * Attaches the main mixer node to the engine and connects it to the
     * default output node. It then prepares and starts the engine.
     */
    private func setupEngine() {
        let inputNode = engine.inputNode
        let outputNode = engine.outputNode
        
        // Use the hardware's native formats to avoid any mismatch.
        let inputFormat = inputNode.outputFormat(forBus: 0)
        let outputFormat = outputNode.outputFormat(forBus: 0)

        engine.attach(mainMixer)

        // Connect the nodes using their native formats.
        engine.connect(inputNode, to: mainMixer, format: inputFormat)
        engine.connect(mainMixer, to: outputNode, format: outputFormat)
        
        // Install a single tap on the input node. This tap will distribute the
        // buffer to all registered consumers.
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] (buffer, when) in
            guard let self = self else { return }
            for consumer in self.bufferConsumers.values {
                consumer(buffer)
            }
        }
        
        // Prepare the engine before starting. This is crucial.
        engine.prepare()
        
        do {
            try engine.start()
            print("Audio engine started successfully.")
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

    /**
     * Starts recording audio from the default input device.
     *
     * If not already recording, it configures a temporary file for the
     * new audio loop and installs a tap on the engine's input node to
     * write the incoming audio buffer to the file.
     */
    func startRecording() {
        guard !isRecording else {
            print("Already recording.")
            return
        }

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        // --- Diagnostic Check ---
        // Ensure the input node is available and has channels.
        guard format.channelCount > 0 else {
            print("ERROR: Microphone not available or has 0 channels.")
            print("Please ensure a microphone is connected and the app has the correct entitlements.")
            return
        }

        let tempDir = FileManager.default.temporaryDirectory
        // Using a unique filename based on the timestamp
        recordingOutputFileURL = tempDir.appendingPathComponent("loop_\(Date().timeIntervalSince1970).caf")

        do {
            outputFile = try AVAudioFile(forWriting: recordingOutputFileURL!, settings: format.settings)
            
            // Define the consumer closure for writing to the file.
            let loopRecorderConsumer: AudioBufferConsumer = { [weak self] buffer in
                guard let self = self, self.isRecording else { return }
                do {
                    try self.outputFile?.write(from: buffer)
                } catch {
                    print("Error writing buffer to file: \(error)")
                }
            }
            
            // Register the file writer as a consumer of the audio stream.
            addAudioBufferConsumer(loopRecorderConsumer, withKey: "loopRecorder")

            isRecording = true
            print("Started recording.")
        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    /**
     * Stops the current recording and creates a new audio loop from it.
     *
     * @param trackID A unique identifier for the new track.
     *
     * This method removes the recording tap, then creates a new AVAudioPlayerNode
     * for the recorded audio file. It loads the audio into a buffer, schedules
     * it for looped playback, and connects the new player to the main mixer.
     */
    func stopRecordingAndCreateLoop(trackID: String) {
        guard isRecording else { return }

        // Unregister the file writer from the audio stream.
        removeAudioBufferConsumer(withKey: "loopRecorder")
        isRecording = false
        
        // De-initialize the output file to ensure all data is written to disk.
        outputFile = nil
        
        print("Stopped recording.")
        
        guard let url = recordingOutputFileURL else {
            print("Recording output URL is nil.")
            return
        }
        
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let format = audioFile.processingFormat
            
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(audioFile.length)) else {
                 print("Could not create buffer")
                 return
            }
            try audioFile.read(into: buffer)

            // Create all nodes for this track
            let playerNode = AVAudioPlayerNode()
            let reverbNode = AVAudioUnitReverb()
            let delayNode = AVAudioUnitDelay()

            // Store them in our dictionary
            tracks[trackID] = TrackNodes(
                player: playerNode,
                reverb: reverbNode,
                delay: delayNode
            )
            
            // Attach all new nodes to the engine
            engine.attach(playerNode)
            engine.attach(reverbNode)
            engine.attach(delayNode)

            // Build the per-track audio graph:
            // Player -> Reverb -> Delay -> MainMixer
            // We connect using 'nil' for the format to let the engine determine
            // the best format, which avoids the -10868 format mismatch error.
            engine.connect(playerNode, to: reverbNode, format: nil)
            engine.connect(reverbNode, to: delayNode, format: nil)
            engine.connect(delayNode, to: mainMixer, format: nil)
            
            // Set initial effect values (i.e., off)
            reverbNode.wetDryMix = 0
            delayNode.wetDryMix = 0

            playerNode.scheduleBuffer(buffer, at: nil, options: .loops)
            
            // A small delay might be needed to ensure the node is ready before playing.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if self.engine.isRunning {
                    playerNode.play()
                }
            }
            
            print("Loop created for trackID: \(trackID)")
        } catch {
            print("Failed to create loop: \(error)")
        }
    }

    /**
     * Adds a new consumer for the live audio input buffer.
     *
     * @param consumer A closure that will be called with each new audio buffer.
     * @param key A unique string to identify the consumer.
     */
    func addAudioBufferConsumer(_ consumer: @escaping AudioBufferConsumer, withKey key: String) {
        bufferConsumers[key] = consumer
        print("Added audio consumer with key: \(key)")
    }
    
    /**
     * Removes an existing consumer of the live audio input buffer.
     *
     * @param key The unique key identifying the consumer to remove.
     */
    func removeAudioBufferConsumer(withKey key: String) {
        if bufferConsumers.removeValue(forKey: key) != nil {
            print("Removed audio consumer with key: \(key)")
        }
    }

    /**
     * Sets the volume for a specific audio track.
     *
     * @param trackID The identifier of the track to modify.
     * @param volume The new volume level, from 0.0 (silent) to 1.0 (full volume).
     */
    func setVolume(forTrack trackID: String, volume: Float) {
        guard let trackNodes = tracks[trackID] else {
            print("Error: Track with ID \(trackID) not found for volume adjustment.")
            return
        }
        // Ensure volume is clamped between 0.0 and 1.0
        trackNodes.player.volume = max(0.0, min(volume, 1.0))
        print("Set volume for track \(trackID) to \(volume)")
    }

    /**
     * Mutes a specific audio track by setting its volume to zero.
     *
     * @param trackID The identifier of the track to mute.
     */
    func muteTrack(trackID: String) {
        guard let trackNodes = tracks[trackID] else {
            print("Error: Track with ID \(trackID) not found for muting.")
            return
        }
        trackNodes.player.volume = 0.0
        print("Muted track \(trackID)")
    }
    
    /**
     * Unmutes a specific audio track by restoring its volume.
     *
     * @param trackID The identifier of the track to unmute.
     * @param volume The volume level to restore the track to.
     */
    func unmuteTrack(trackID: String, volume: Float) {
        guard let trackNodes = tracks[trackID] else {
            print("Error: Track with ID \(trackID) not found for unmuting.")
            return
        }
        trackNodes.player.volume = max(0.0, min(volume, 1.0))
        print("Unmuted track \(trackID) to volume \(volume)")
    }

    /**
     * Starts playback for all created audio loops.
     *
     * Iterates through all existing player nodes and calls the play() method on each.
     */
    func playAll() {
        guard engine.isRunning else {
             print("Engine not running.")
             return
        }
        for trackNodes in tracks.values {
            trackNodes.player.play()
        }
        print("Playing all loops.")
    }

    /**
     * Stops playback for all created audio loops.
     *
     * Iterates through all existing player nodes and calls the stop() method on each.
     */
    func stopAll() {
        for trackNodes in tracks.values {
            trackNodes.player.stop()
        }
        print("Stopped all loops.")
    }

    /**
     * Sets the reverb level for a specific track.
     *
     * @param trackID The identifier of the track to modify.
     * @param value The wet/dry mix for the reverb, from 0 (dry) to 100 (wet).
     */
    func setReverb(for trackID: String, to value: Float) {
        guard let trackNodes = tracks[trackID] else {
            print("Error: Could not find track with ID \(trackID) to set reverb.")
            return
        }
        // The value is expected to be 0-100, so we clamp and normalize it.
        trackNodes.reverb.wetDryMix = max(0, min(100, value))
        print("Set reverb for track \(trackID) to \(value)")
    }

    /**
     * Sets the delay level for a specific track.
     *
     * @param trackID The identifier of the track to modify.
     * @param value The wet/dry mix for the delay, from 0 (dry) to 100 (wet).
     */
    func setDelay(for trackID: String, to value: Float) {
        guard let trackNodes = tracks[trackID] else {
            print("Error: Could not find track with ID \(trackID) to set delay.")
            return
        }
        trackNodes.delay.wetDryMix = max(0, min(100, value))
        print("Set delay for track \(trackID) to \(value)")
    }
} 