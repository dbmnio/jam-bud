# JamSession3: AI Music Looper Agent

This project is an innovative music creation application that reimagines the music-making process as an interactive conversation with an AI. It functions as a voice-controlled music loop pedal powered by a sophisticated AI agent, allowing users to record, layer, modify, and generate musical tracks using natural language commands.

## Getting Started

Follow these instructions to set up and run the application on your local machine.

### Prerequisites

-   macOS with Xcode installed
-   Python 3.8+

### 0. Clone the repo

```bash
git clone <repo url>
cd jam-bud
```

### 1. Backend Setup (Python Server)

The Python backend uses FastAPI to process commands from the native macOS application.

```bash
# 1. Navigate to the python directory
cd python

# 2. Create a Python virtual environment
python3 -m venv jamsession3

# 3. Activate the virtual environment
source jamsession3/bin/activate

# 4. Install the required dependencies
pip install -r requirements.txt

# 5. Include the necessary environment variables
printf 'OPENAI_API_KEY=<your openAI api key>\nREPLICATE_API_TOKEN=<your replicate api token>\n' > .env

# 5. Start the server
# The server will run on http://127.0.0.1:8000
./run_server.sh
```

### 2. Frontend Setup (macOS App)

The frontend is a native macOS application built with Swift and SwiftUI.

1.  Open the `JamSession3.xcodeproj` file in Xcode.
2.  Ensure the Python backend server is running.
3.  Click the "Run" button (or press `Cmd+R`) in Xcode to build and run the application.

## High-Level Architecture

The application uses a hybrid architecture that separates the AI logic from the real-time audio processing to ensure low-latency performance.

-   **Frontend (macOS Native App)**: A Swift/SwiftUI application responsible for the user interface and all real-time audio operations. It uses Apple's native frameworks for optimal performance:
    -   `AVFoundation` (`AVAudioEngine`): Manages recording, playback, mixing, and audio effects with minimal latency.
    -   `SFSpeechRecognizer`: Handles real-time, on-device speech-to-text.
-   **Backend (Python Server)**: A Python server powered by **FastAPI** that hosts the core AI logic.
    -   **LangGraph**: Orchestrates the complex, stateful workflows required for musical composition, managing the conversation and calling on various tools.
-   **Communication Bridge**: The frontend and backend communicate over a local network. The Swift app sends transcribed voice commands to the Python server via HTTP requests, and the server responds with JSON payloads containing instructions for the audio engine or text for the agent to speak.

## Directory Structure

```
.
├── JamSession3/              # Source code for the native macOS Swift application
├── JamSession3.xcodeproj/      # Xcode project file
├── JamSession3Tests/           # Unit tests for the macOS app
├── JamSession3UITests/         # UI tests for the macOS app
├── python/                   # Source code for the Python backend
│   ├── main.py               # FastAPI server application
│   └── run_server.sh         # Script to start the backend server
├── _brainlift/               # Initial research and brainstorming documents
└── _docs/                    # Project documentation and overviews
``` 