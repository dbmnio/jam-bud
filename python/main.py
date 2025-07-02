from fastapi import FastAPI
from pydantic import BaseModel
import uvicorn
from typing import List, Dict, TypedDict, Optional

# --- LangGraph State Definition ---

class Track(TypedDict):
    """Represents a single audio track in the session."""
    id: str
    name: str
    volume: float
    is_playing: bool
    # path: str # To be added later

class AgentState(TypedDict):
    """The complete state of our music agent."""
    tracks: List[Track]
    command: str
    response: Dict
    modification_args: Optional[Dict]
    next_track_id: int

# --- Agent Nodes ---

def router_node(state: AgentState):
    """
    Uses simple keyword matching to interpret the user's command and route to the correct node.
    This is a placeholder for the future LLM-based router.
    """
    command = state.get("command", "").lower()
    print(f"Routing command: {command}")

    # Use exact matching for commands sent by the dedicated UI button.
    if command == "record":
        return "record_node"
    elif command == "stop":
        return "stop_node"
    elif "quieter" in command or "lower" in command or "volume" in command:
        # Simple parsing for now. LLM will handle this properly.
        # Assume it applies to the last track for now.
        if state["tracks"]:
            track_id = state["tracks"][-1]["id"]
            state["modification_args"] = {"track_id": track_id, "volume": 0.5} # Hardcoded for now
            return "modify_track_node"
        else:
            return "fallback_node"
    elif "mute" in command or "unmute" in command:
        # Simple parsing for now. LLM will handle this properly.
        # Assume it applies to the last track for now.
        if state["tracks"]:
            track_id = state["tracks"][-1]["id"]
            state["modification_args"] = {"track_id": track_id}
            return "toggle_playback_node"
        else:
            return "fallback_node"
    else:
        return "fallback_node"


def record_node(state: AgentState):
    """Prepares the command to start recording."""
    print("Executing record node")
    state["response"] = {"action": "start_recording"}
    return state

def stop_node(state: AgentState):
    """Prepares the command to stop recording and create a new track."""
    print("Executing stop node")
    new_track_id = f"track_{state['next_track_id']}"
    
    # Update internal state
    new_track = Track(id=new_track_id, name=f"Loop {state['next_track_id']}", volume=1.0, is_playing=True)
    state["tracks"].append(new_track)
    state["next_track_id"] += 1
    
    state["response"] = {"action": "stop_recording_and_create_loop", "track_id": new_track_id}
    return state

def modify_track_node(state: AgentState):
    """Updates the state and prepares the command for the Swift audio engine."""
    print("Executing modify_track_node")
    args = state.get("modification_args")
    if not args:
        return "fallback_node"

    track_id = args["track_id"]
    new_volume = args["volume"]

    # Update the internal state
    for track in state["tracks"]:
        if track["id"] == track_id:
            track["volume"] = new_volume
            print(f"Updated track {track_id} volume to {new_volume}")
            break
            
    # Prepare the command for Swift
    state["response"] = {
        "action": "set_volume",
        "track_id": track_id,
        "volume": new_volume
    }
    return state

def toggle_playback_node(state: AgentState):
    """Updates the state and prepares the command for the Swift audio engine to mute or unmute."""
    print("Executing toggle_playback_node")
    args = state.get("modification_args")
    if not args:
        return "fallback_node"

    track_id = args["track_id"]
    
    action = ""
    volume_for_unmute = 1.0 # Default volume

    # Update the internal state
    for track in state["tracks"]:
        if track["id"] == track_id:
            # Toggle the playing state
            track["is_playing"] = not track["is_playing"]
            volume_for_unmute = track["volume"]
            if track["is_playing"]:
                action = "unmute_track"
            else:
                action = "mute_track"
            print(f"Toggled track {track_id} to is_playing: {track['is_playing']}")
            break
            
    # Prepare the command for Swift
    state["response"] = {
        "action": action,
        "track_id": track_id,
        "volume": volume_for_unmute # Only used for unmuting, ignored for muting
    }
    return state

def fallback_node(state: AgentState):
    """Handles commands that are not understood."""
    print("Executing fallback_node")
    state["response"] = {"speak": "I'm not sure how to do that."}
    return state

# --- LangGraph Setup ---
# In a real LangGraph app, you would define a Graph object here.
# For now, we will simulate the graph execution flow in the endpoint.

# A simple dictionary to hold the agent's state.
initial_state = AgentState(tracks=[], command="", response={}, modification_args=None, next_track_id=0)

node_map = {
    "record_node": record_node,
    "stop_node": stop_node,
    "modify_track_node": modify_track_node,
    "toggle_playback_node": toggle_playback_node,
    "fallback_node": fallback_node
}

# --- FastAPI Server ---

class Command(BaseModel):
    text: str

app = FastAPI()

@app.post("/command")
async def process_command(command: Command):
    """
    Receives a command, runs it through the mock-LangGraph flow, and returns the response.
    """
    print(f"Received command: {command.text}")
    
    # 1. Set the command in the state
    current_state = initial_state.copy()
    current_state["command"] = command.text

    # 2. Run the router to decide the next step
    next_node_name = router_node(current_state)
    
    # 3. Execute the chosen node
    if next_node_name in node_map:
        node_function = node_map[next_node_name]
        final_state = node_function(current_state)
        response = final_state.get("response", {})
    else:
        response = {"speak": "Error: Could not find a path to handle that command."}

    # Persist state changes (simplified for now)
    initial_state.update(current_state)
            
    print(f"Responding with: {response}")
    return response

# To run this server, use the command from the `python` directory:
# uvicorn main:app --host 127.0.0.1 --port 8000 