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

1. **Native Audio Engine (Swift):** ✅ 
   * Implement the AVAudioEngine.  
   * Create the core audio graph: multiple AVAudioPlayerNode instances feeding into an AVAudioMixerNode, which then connects to the main output.  
   * Implement functions for:  
     * startRecording()  
     * stopRecordingAndCreateLoop(trackID: String): This function stops recording, saves the audio to a temporary file, and schedules it to play on a new AVAudioPlayerNode.  
     * playAll()  
     * stopAll()  
2. **Agent-to-Audio Control (Swift):** ✅ 
   * Modify the network client to parse action commands from the Python agent's JSON response (e.g., {"action": "start\_recording"}).  
   * Create a switch statement to call the appropriate AVAudioEngine function based on the received action.  
3. **Basic Agent Logic (Python):** ✅ 
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

The goal is to replace text input with real voice commands and make the agent capable of understanding natural language. This phase also includes key UX improvements, such as a dedicated record/stop button and non-destructive track muting, to create a more intuitive and flexible user workflow.

#### **Tasks:**

1. **Voice Integration (Swift):** ✅ 
   * Integrate SFSpeechRecognizer for speech-to-text. Implement a "push-to-talk" mechanic (e.g., holding a key).  
   * When transcription is complete, send the resulting text to the Python agent.  
   * Integrate AVSpeechSynthesizer for text-to-speech. The app should speak any text returned in a {"speak": "..."} payload from the agent.  
2. **Agent Intelligence (Python):** ✅ 
   * Enhance the LangGraph State to be a list of track objects, each with an id, name, volume, etc.  
   * Upgrade the RouterNode to use an LLM (via LangChain) to parse user intent. It should be able to understand commands like "make the first loop quieter" and translate it into a structured command: {"action": "set\_volume", "track\_id": "track\_001", "value": 0.7}.  
   * Add a ModifyTrackNode to the graph that handles these structured commands.  
3. **Native Audio Enhancements (Swift):** ✅ 
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
3. **Project Management (Open/Save):**
    *   **Project Bundle:** Define a file bundle format (e.g., `.jamproject`). This will be a directory containing the project-specific `project.sqlite` database and an `audio/` folder for all associated loops.
    *   **Backend Updates:** Modify the `HistoryManager` to be initialized with a path to the active project's database file. All audio file paths in the state snapshots must be stored relative to the project bundle's root.
    *   **Frontend UI:** Implement a standard "File" menu in the SwiftUI app with "New", "Open", "Save", and "Save As" options, using native `NSOpenPanel` and `NSSavePanel` for the dialogs.
    *   **State Management:** The Swift app will be responsible for managing the "active project context" and ensuring the `HistoryManager` and `AudioManager` are working with the correct files.
4. **Finalization:**  
   * Implement robust error handling for both the native and Python components.  
   * Add comprehensive logging to help debug issues.  

#### **✅** Testing & Verification for Phase 4:

* Archive the app in Xcode.  
* Install the .app file on a clean macOS machine (or a different user account).  
* **Success Criteria:** The application launches, the Python backend starts automatically, and all features from Phases 1-3 work correctly without requiring any manual setup from the user.
*   Create a new project, save it, close the app, and re-open the project. **Expected:** All tracks and history are loaded correctly.
*   Use "Save As" to create a duplicate of a project. **Expected:** A new, independent project bundle is created on disk.

## **Phase 5: Timeline, Arrangement & Semantic Awareness (Future)**

The goal is to evolve the application into a powerful, timeline-based sequencer that understands user intent and musical context, allowing for complex song arrangement.

#### **Tasks:**

1.  **Advanced State Model (Python):**
    *   Enhance the agent's state to include a list of `Section` objects (e.g., intro, verse, chorus) with defined start/end times and a list of user-defined `aliases`.
    *   Add a `startTime` property to each `Track` object to position it on a timeline.
2.  **Advanced Agent Logic (Python):**
    *   Implement new agent tools for arrangement, such as `move_clip`, `define_section`, and `set_loop_region`.
    *   Implement a `name_section` tool to allow users to explicitly name sections (e.g., "Name this section the chorus").
    *   Implement an `analyze_and_find_section` tool to handle implicit, descriptive commands (e.g., "Loop over the quiet part").
3.  **Audio Analysis Engine (Python):**
    *   Integrate an audio analysis library (e.g., `librosa`) to extract technical features like volume, tempo, and beat structure from audio clips.
    *   (Stretch Goal) Integrate multimodal LLM capabilities to analyze and understand semantic descriptions of music (e.g., "dreamy," "energetic").
4.  **Playback Engine Upgrade (Swift):**
    *   Refactor the `AudioManager` to manage a playback timeline and schedule audio clips at specific start times using `scheduleSegment`.
    *   Implement a "playback head" that can be moved to different sections on the timeline.
5.  **UI for Arrangement (SwiftUI):**
    *   Develop a basic visual representation of the timeline, showing the sections and the audio clips within them.
6.  **Advanced Undo System (Undo Tree):**
    *   **Backend Logic (Python):** Activate the full branching capabilities of the `HistoryManager`. Implement agent tools for `redo` (including branch selection logic), `go_to_checkpoint`, `name_checkpoint`, and `query_history`.
    *   **Frontend UI (SwiftUI):** Design and implement a visual undo tree graph UI. This view will allow users to see their project's entire history, view different branches, and click any node to instantly revert the session state to that point.
    *   **Agent Interaction:** Enhance the agent with the ability to have a dialogue about the project's history (e.g., "You have two branches here. Which one do you want to follow?").

#### **✅** Testing & Verification for Phase 5:

*   Speak "Loop over the chorus." **Expected:** The app correctly identifies the chorus section and loops it.
*   Speak "Take the guitar from the intro and move it to the chorus." **Expected:** The guitar track is audibly moved and layered into the chorus section.
*   Speak "Find the quietest part and loop it." **Expected:** The agent analyzes the audio, finds the section with the lowest RMS volume, and begins looping it.
*   Speak "Let's call this part 'the bridge'." **Expected:** The current section can now be referred to as "the bridge" in subsequent commands.
*   Speak "Checkpoint this as 'Verse Idea 2'." **Expected:** The agent saves the current state with a name.
*   After making changes, speak "Go back to 'Verse Idea 2'." **Expected:** The application state reverts to the named checkpoint.
*   Open the history view. **Expected:** A graph of the project's history is visible and navigable.

---

## Appendix: Design Discussion on Project Management (Open/Save)

This section documents the decision to add multi-project support to the application.

### The Need for Project Scoping

The initial implementation plan did not explicitly define how users would manage different musical projects. The system was designed as a single, continuous session. To turn the application into a practical tool, users need the ability to create, save, and load distinct projects.

### The Implementation Strategy

The solution involves three main components:

1.  **Project Bundles:** To keep all related data together, we will adopt a project bundle format (e.g., `.jamproject`). This is a standard macOS practice where a directory is treated as a single file by the user. Each bundle will contain the project-specific SQLite database for history and a dedicated `audio/` folder for all its associated sound files.
2.  **Database Scoping:** Instead of a single global database, each project bundle will have its own `project.sqlite` file. This is a simpler and more robust approach than adding a `project_id` to a global table, as it completely isolates project data and simplifies backup and file management for the user.
3.  **Standard UI:** The application will feature a standard "File" menu with "New", "Open", "Save", and "Save As" functionality, using native macOS dialogs to handle user interaction.

### Rationale for Deferring to Phase 4

The decision was made to place this feature in Phase 4 after confirming that implementing it later poses **no significant risk of a major refactor**.

The key reasons are:

*   **It is an Additive Feature:** Project management is a "context" change, not a core "logic" change. The agent's creative and musical functions do not need to be rewritten; they only need to be told which project's files they are working on.
*   **Changes are Contained:** The necessary modifications are well-isolated within the `HistoryManager` (which will be given a path to the correct database) and the `AudioManager` (which will be given a path to the correct audio directory).
*   **No Data Migration:** As this will be implemented before public use, there is no need to write complex or risky scripts to migrate user data from an old format.

By adding this in Phase 4, we can focus on the core creative tools in Phase 3 while being confident that this essential file management functionality can be integrated smoothly later on.