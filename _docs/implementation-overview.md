# **Implementation Plan: AI Music Looper Agent**

This document outlines a phased implementation plan for the AI Music Looper Agent, based on the project overview and recommended tech stack. The primary goal is to achieve a functional Minimal Viable Product (MVP) rapidly, with each phase delivering a testable set of features.

## **Guiding Principles**

* **MVP First:** The initial focus is on the core audio looping functionality controlled by a basic agent. Advanced AI and UI features will be layered on top.  
* **Isolate Complexity:** Separate the real-time audio engine (macOS/Swift) from the AI logic (Python/LangGraph).  
* **Testable Phases:** Each phase concludes with a clear set of functionalities that can be manually tested to ensure correctness and prevent regressions.

## **Phase 0: Foundation & Project Setup (1-2 Days)**

The goal of this phase is to establish the project structure and the communication bridge between the native front-end and the Python back-end.

#### **Tasks:**

1. **Python Project Setup:** ✅ 
   * Create a new Python project directory.  
   * Set up a virtual environment (venv).  
   * Install initial dependencies: langchain, langgraph, fastapi, uvicorn.  
2. **macOS Project Setup:** ✅
   * Create a new Xcode project using the SwiftUI App template.  
   * Confirm project settings for macOS deployment.  
3. **Communication Bridge:** ✅
   * **Python:** Create a basic FastAPI server with a single POST endpoint (e.g., /command) that accepts a JSON payload (e.g., {"text": "user command"}) and returns a JSON response (e.g., {"action": "none"}).  
   * **Swift:** Write a simple network client to send a POST request to the local Python server (http://127.0.0.1:8000/command) and parse the JSON response.

#### **✅** Testing & Verification for Phase 0:

* Run the Python FastAPI server.  
* Run the macOS app.  
* Trigger an action in the app (e.g., a button press) that sends a hardcoded command like "record" to the Python server.  
* **Success Criteria:** Verify that the command is received and printed in the Python console, and the macOS app correctly receives and prints the JSON response from the server.

## **Phase 1: The Core Music Loop \- MVP (3-5 Days)**

The goal is a functional, non-UI application where a user can layer audio loops controlled by simple, text-based commands sent to the agent. This is the MVP.

#### **Tasks:**

1. **Native Audio Engine (Swift):**  
   * Implement the AVAudioEngine.  
   * Create the core audio graph: multiple AVAudioPlayerNode instances feeding into an AVAudioMixerNode, which then connects to the main output.  
   * Implement functions for:  
     * startRecording()  
     * stopRecordingAndCreateLoop(trackID: String): This function stops recording, saves the audio to a temporary file, and schedules it to play on a new AVAudioPlayerNode.  
     * playAll()  
     * stopAll()  
2. **Agent-to-Audio Control (Swift):**  
   * Modify the network client to parse action commands from the Python agent's JSON response (e.g., {"action": "start\_recording"}).  
   * Create a switch statement to call the appropriate AVAudioEngine function based on the received action.  
3. **Basic Agent Logic (Python):**  
   * Create the initial LangGraph State, which can be as simple as {"track\_count": int}.  
   * Implement a single RouterNode in LangGraph. This node will not use an LLM yet; it will use simple if/else logic to parse commands like "record", "stop", "play".  
   * Based on the command, the node will return the appropriate JSON action to be sent back to the Swift app.

#### **✅** Testing & Verification for Phase 1:

* Use a tool like curl or Postman to send commands directly to the Python server, simulating the app.  
* Send {"text": "record"}. **Expected:** The app starts recording audio.  
* Send {"text": "stop"}. **Expected:** The app stops recording and immediately begins playing the first loop.  
* Send {"text": "record"} again. **Expected:** The app records a second track while the first continues to loop.  
* Send {"text": "stop"} again. **Expected:** The second loop is added and plays in sync with the first.

## **Phase 2: Introducing Voice & AI Intelligence (3-4 Days)**

The goal is to replace text input with real voice commands and make the agent capable of understanding natural language.

#### **Tasks:**

1. **Voice Integration (Swift):**  
   * Integrate SFSpeechRecognizer for speech-to-text. Implement a "push-to-talk" mechanic (e.g., holding a key).  
   * When transcription is complete, send the resulting text to the Python agent.  
   * Integrate AVSpeechSynthesizer for text-to-speech. The app should speak any text returned in a {"speak": "..."} payload from the agent.  
2. **Agent Intelligence (Python):**  
   * Enhance the LangGraph State to be a list of track objects, each with an id, name, volume, etc.  
   * Upgrade the RouterNode to use an LLM (via LangChain) to parse user intent. It should be able to understand commands like "make the first loop quieter" and translate it into a structured command: {"action": "set\_volume", "track\_id": "track\_001", "value": 0.7}.  
   * Add a ModifyTrackNode to the graph that handles these structured commands.  
3. **Native Audio Enhancements (Swift):**  
   * Add functions to the AVAudioEngine controller to handle the new actions, like setVolume(trackID: String, volume: Float).

#### **✅** Testing & Verification for Phase 2:

* Speak the command "record a loop". **Expected:** The app records and loops audio.  
* Speak the command "make that loop quieter". **Expected:** The volume of the loop visibly (or audibly) decreases.  
* Speak a command the agent doesn't understand. **Expected:** The agent responds with a spoken message like "I'm not sure how to do that."

## **Phase 3: Advanced Features & Creative Tools (4-6 Days)**

The goal is to implement the core creative features that make the app powerful and unique.

#### **Tasks:**

1. **Music Generation (Python):**  
   * Implement a MusicGenerationNode in LangGraph.  
   * This node will call an external music generation API, passing the current State's tempo and key as parameters.  
   * It will receive the generated audio, save it, and update the State with the new track.  
2. **Undo/Redo Functionality (Python/LangGraph):**  
   * Implement a MemorySaver checkpoint for the LangGraph.  
   * Create an UndoNode that reverts the graph to the previous checkpoint.  
3. **Creative Suggestions (Python):**  
   * Implement an AnalysisNode that can summarize the current state (e.g., "A 120 BPM track in A Minor with guitar and drums").  
   * Feed this summary to a SuggestionNode that uses an LLM to generate creative ideas.  
4. **Audio Effects (Swift):**  
   * Integrate native Audio Unit effects (e.g., AVAudioUnitReverb, AVAudioUnitDelay) into the AVAudioEngine graph.  
   * Expose controls for these effects so the Python agent can enable/disable them on specific tracks.  
5. **Basic UI (SwiftUI):**  
   * Develop a minimal UI that visualizes the current tracks in the State.  
   * Include a "listening" indicator and basic transport controls. The UI should be a read-only reflection of the agent's state.

#### **✅** Testing & Verification for Phase 3:

* Speak "add a bassline". **Expected:** A new, musically coherent bassline track is added.  
* After adding a track, speak "undo that". **Expected:** The last track is removed.  
* Speak "what should I add next?". **Expected:** The agent provides a relevant, spoken suggestion.  
* Speak "put some reverb on the guitar". **Expected:** The reverb effect is audibly applied.

## **Phase 4: Packaging & Final Polish (2-3 Days)**

The goal is to turn the project into a distributable macOS application.

#### **Tasks:**

1. **Packaging the Python Backend:**  
   * Use a tool like **PyInstaller** to bundle the Python script, its dependencies, and the LangGraph agent into a single executable file.  
2. **Application Integration:**  
   * Bundle the Python executable inside the main macOS application package (.app).  
   * Modify the Swift app to launch the Python executable as a background child process when the app starts and terminate it on quit.  
3. **Finalization:**  
   * Implement robust error handling for both the native and Python components.  
   * Add comprehensive logging to help debug issues.  
   * Perform end-to-end regression testing of all features.

#### **✅** Testing & Verification for Phase 4:

* Archive the app in Xcode.  
* Install the .app file on a clean macOS machine (or a different user account).  
* **Success Criteria:** The application launches, the Python backend starts automatically, and all features from Phases 1-3 work correctly without requiring any manual setup from the user.