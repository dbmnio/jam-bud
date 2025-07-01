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
class AudioManager {

    private var engine = AVAudioEngine()
    private var mainMixer = AVAudioMixerNode()
    private var playerNodes = [AVAudioPlayerNode]()
    private var isRecording = false
    private var recordingOutputFileURL: URL?
    private var outputFile: AVAudioFile?

    /**
     * Initializes the AudioManager.
     *
     * Sets up the shared audio session for recording and playback,
     * then configures and starts the AVAudioEngine.
     */
    init() {
        setupEngine()
    }

    /**
     * Configures the AVAudioEngine and its audio graph.
     *
     * Attaches the main mixer node to the engine and connects it to the
     * default output node. It then starts the engine.
     */
    private func setupEngine() {
        engine.attach(mainMixer)
        engine.connect(mainMixer, to: engine.outputNode, format: nil)
        
        do {
            try engine.start()
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
        let tempDir = FileManager.default.temporaryDirectory
        // Using a unique filename based on the timestamp
        recordingOutputFileURL = tempDir.appendingPathComponent("loop_\(Date().timeIntervalSince1970).caf")

        do {
            outputFile = try AVAudioFile(forWriting: recordingOutputFileURL!, settings: format.settings)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] (buffer, when) in
                do {
                    try self?.outputFile?.write(from: buffer)
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

        engine.inputNode.removeTap(onBus: 0)
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
        for player in playerNodes {
            player.play()
        }
        print("Playing all loops.")
    }

    /**
     * Stops playback for all created audio loops.
     *
     * Iterates through all existing player nodes and calls the stop() method on each.
     */
    func stopAll() {
        for player in playerNodes {
            player.stop()
        }
        print("Stopped all loops.")
    }
} 