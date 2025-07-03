from fastapi import FastAPI
from pydantic import BaseModel
import uvicorn
from typing import List, Dict, TypedDict, Optional

from history_manager import HistoryManager
from nodes.music_generation_node import music_generation_node
from nodes.suggestion_nodes import analysis_node, suggestion_node

# --- History Manager Setup ---
# This will manage our state history in a SQLite database.
# For now, we use a single, hardcoded DB file.
history = HistoryManager("project.db")

# --- LangGraph State Definition ---

class Track(TypedDict):
    """Represents a single audio track in the session."""
    id: str
    name: str
    volume: float
    is_playing: bool
    path: Optional[str]

class AgentState(TypedDict):
    """The complete state of our music agent."""
    history_node_id: Optional[str] # The current node in our undo tree
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
    elif command == "undo":
        return "undo_node"
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
    elif "add a beat" in command or "add drums" in command or "generate music" in command:
        return "music_generation_node"
    elif "what should i add" in command or "suggestion" in command or "what's next" in command:
        return "analysis_node" # Start the suggestion flow
    else:
        return "fallback_node"

def analysis_node_router(state: AgentState):
    """A simple router that always directs from analysis to suggestion."""
    return "suggestion_node"

def record_node(state: AgentState, history: HistoryManager):
    """Prepares the command to start recording. This is a non-state-changing action."""
    print("Executing record node")
    state["response"] = {"action": "start_recording"}
    # No state is committed here because recording is transient.
    # The new state is only committed when recording stops.
    return state

def stop_node(state: AgentState, history: HistoryManager):
    """Stops recording, creates a new track, and commits the new state."""
    print("Executing stop node")

    # Create a deep copy to modify
    new_state = state.copy()
    new_state["tracks"] = [t.copy() for t in state["tracks"]]

    new_track_id = f"track_{state['next_track_id']}"
    
    # Update internal state
    new_track = Track(id=new_track_id, name=f"Loop {state['next_track_id']}", volume=1.0, is_playing=True, path=None)
    new_state["tracks"].append(new_track)
    new_state["next_track_id"] += 1
    
    new_state["response"] = {"action": "stop_recording_and_create_loop", "track_id": new_track_id}

    # Commit the new state to the history tree.
    # The commit method will generate an ID and add it to the new_state object.
    parent_node_id = state.get("history_node_id")
    history.commit(new_state, parent_node_id)

    return new_state

def modify_track_node(state: AgentState, history: HistoryManager):
    """Updates a track's state and commits the change to history."""
    print("Executing modify_track_node")
    args = state.get("modification_args")
    if not args:
        return "fallback_node"

    new_state = state.copy()
    new_state["tracks"] = [t.copy() for t in state["tracks"]]

    track_id = args["track_id"]
    new_volume = args["volume"]

    # Update the internal state
    for track in new_state["tracks"]:
        if track["id"] == track_id:
            track["volume"] = new_volume
            print(f"Updated track {track_id} volume to {new_volume}")
            break
            
    # Prepare the command for Swift
    new_state["response"] = {
        "action": "set_volume",
        "track_id": track_id,
        "volume": new_volume
    }

    # Commit the new state
    parent_node_id = state.get("history_node_id")
    history.commit(new_state, parent_node_id)
    
    return new_state

def toggle_playback_node(state: AgentState, history: HistoryManager):
    """Toggles a track's playback state and commits the change."""
    print("Executing toggle_playback_node")
    args = state.get("modification_args")
    if not args:
        return "fallback_node"

    new_state = state.copy()
    new_state["tracks"] = [t.copy() for t in state["tracks"]]

    track_id = args["track_id"]
    
    action = ""
    volume_for_unmute = 1.0 # Default volume

    # Update the internal state
    for track in new_state["tracks"]:
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
    new_state["response"] = {
        "action": action,
        "track_id": track_id,
        "volume": volume_for_unmute # Only used for unmuting, ignored for muting
    }

    # Commit the new state
    parent_node_id = state.get("history_node_id")
    history.commit(new_state, parent_node_id)
    
    return new_state

def undo_node(state: AgentState, history: HistoryManager):
    """Loads the parent state from the history manager."""
    print("Executing undo_node")
    current_node_id = state.get("history_node_id")

    # If there's no history or we are at the root, we can't undo.
    parent_id = history.get_parent_id(current_node_id) if current_node_id else None
    if not parent_id:
        # Return the current state but with a message for the user.
        new_state = state.copy()
        new_state["response"] = {"speak": "You are at the beginning of the history."}
        return new_state

    reverted_state = history.get_state(parent_id)

    if reverted_state:
        # The new application state is the reverted state.
        # We now construct a response for the client.
        # To avoid circular references, the payload for the 'load_state' action
        # must be a clean copy of the state data.
        state_payload = reverted_state.copy()
        if "response" in state_payload:
            del state_payload["response"]

        reverted_state["response"] = {
            "action": "load_state",
            "state": state_payload
        }
        return reverted_state
    else:
        # This is an unlikely error case, but we handle it gracefully.
        new_state = state.copy()
        new_state["response"] = {"speak": "I could not find the previous state to restore."}
        return new_state


def fallback_node(state: AgentState, history: HistoryManager):
    """Handles commands that are not understood."""
    print("Executing fallback_node")
    state["response"] = {"speak": "I'm not sure how to do that."}
    return state

# --- LangGraph Setup ---
def get_initial_state() -> AgentState:
    """Returns the template for a new, empty session state."""
    return {
        "history_node_id": None,
        "tracks": [],
        "command": "",
        "response": {},
        "modification_args": None,
        "next_track_id": 0,
    }

# Ensure the database has a root node. If not, create one.
if history.get_root_node_id() is None:
    print("No root node found in database. Creating initial state.")
    initial_state = get_initial_state()
    # The commit method will generate the ID and add it to the initial_state dict.
    history.commit(initial_state, parent_id=None)

node_map = {
    "record_node": record_node,
    "stop_node": stop_node,
    "modify_track_node": modify_track_node,
    "toggle_playback_node": toggle_playback_node,
    "undo_node": undo_node,
    "music_generation_node": music_generation_node,
    "analysis_node": analysis_node,
    "suggestion_node": suggestion_node,
    "fallback_node": fallback_node
}

# --- FastAPI Server ---

class Command(BaseModel):
    text: str
    history_node_id: Optional[str] = None # The client can omit this for the first request

app = FastAPI()

@app.post("/command")
async def process_command(command: Command):
    """
    Receives a command, runs it through the mock-LangGraph flow, and returns the response.
    This endpoint is stateless. It loads the required state from the DB for each call.
    """
    print(f"Received command: '{command.text}' from node: {command.history_node_id}")

    request_node_id = command.history_node_id

    # If the client doesn't provide a node ID (i.e., it's the first request),
    # we find the root of the history tree to use as the base state.
    if not request_node_id:
        print("No history node provided, finding root node.")
        request_node_id = history.get_root_node_id()

    # Load the state for the current request from the database.
    state_for_request = history.get_state(request_node_id)
    if not state_for_request:
        return {"speak": f"Error: Could not find history for node '{request_node_id}'."}
    
    # 1. Set the command in the state for this request
    state_for_request["command"] = command.text

    # 2. Run the router to find the first node
    current_node_name = router_node(state_for_request)
    
    # 3. Execute the node(s) in a loop until a final response is ready.
    # This simulates a multi-step graph execution.
    while True:
        if current_node_name not in node_map:
            response = {"speak": f"Error: Could not find node '{current_node_name}'."}
            break

        node_function = node_map[current_node_name]
        state_for_request = node_function(state_for_request, history)
        
        # If the node produced a response for the user, we are done.
        if "response" in state_for_request and state_for_request["response"]:
            # Ensure the response always contains the latest history node ID
            final_state = state_for_request
            final_state["response"]["history_node_id"] = final_state.get("history_node_id")
            response = final_state.get("response", {})
            break
        
        # --- Hardcoded routing for multi-step flows ---
        # In a real LangGraph app, this would be handled by conditional edges.
        if current_node_name == "analysis_node":
            current_node_name = analysis_node_router(state_for_request)
        else:
            # If no specific routing is defined, the flow ends.
            # This shouldn't be reached if nodes are designed correctly.
            response = {"speak": "An unexpected error occurred in the agent's logic."}
            break
            
    print(f"Responding with: {response}")
    return response

# To run this server, use the command from the `python` directory:
# uvicorn main:app --host 127.0.0.1 --port 8000 