from dotenv import load_dotenv
# Load environment variables from .env file
load_dotenv()


from fastapi import FastAPI
from pydantic import BaseModel, Field
import uvicorn
from typing import List, Dict, TypedDict, Optional
from functools import partial

from langchain_core.tools import tool
from langchain_openai import ChatOpenAI
from langgraph.graph import StateGraph, END

from history_manager import HistoryManager
from nodes.music_generation_node import music_generation_node
from nodes.suggestion_nodes import analysis_node, suggestion_node


# --- State Definition ---

class Track(TypedDict):
    id: str
    name: str
    volume: float
    is_playing: bool
    path: Optional[str]
    reverb: float
    delay: float

class AgentState(TypedDict):
    history_node_id: Optional[str]
    tracks: List[Track]
    command: str
    response: Dict
    modification_args: Optional[Dict]
    next_track_id: int
    next_node: Optional[str] # The decision from the router

# --- Node Functions ---

def no_op_node(state: AgentState, history: HistoryManager):
    print("Executing no_op_node")
    state_payload = state.copy()
    if "response" in state_payload: del state_payload["response"]
    state["response"] = {"action": "load_state", "state": state_payload}
    return state

def record_node(state: AgentState, history: HistoryManager):
    print("Executing record node")
    state["response"] = {"action": "start_recording"}
    return state

def stop_node(state: AgentState, history: HistoryManager):
    print("Executing stop node")
    new_state = state.copy()
    new_state["tracks"] = [t.copy() for t in state["tracks"]]
    new_track_id = f"track_{state['next_track_id']}"
    new_track = Track(id=new_track_id, name=f"Loop {state['next_track_id']}", volume=1.0, is_playing=True, path=None, reverb=0.0, delay=0.0)
    new_state["tracks"].append(new_track)
    new_state["next_track_id"] += 1
    new_state["response"] = {"action": "stop_recording_and_create_loop", "track": new_track}
    history.commit(new_state, state.get("history_node_id"))
    return new_state

def modify_track_node(state: AgentState, history: HistoryManager):
    print("Executing modify_track_node")
    args = state.get("modification_args")
    if not args or "track_id" not in args: return fallback_node(state, history)
    
    new_state = state.copy()
    new_state["tracks"] = [t.copy() for t in state["tracks"]]
    track_id = args["track_id"]
    response_args = {}
    action_key = ""

    for track in new_state["tracks"]:
        if track["id"] == track_id:
            if "volume" in args:
                action_key = "volume"
                track["volume"] = args["volume"]
                response_args = {"volume": args["volume"]}
            elif "reverb" in args:
                action_key = "reverb"
                track["reverb"] = args["reverb"]
                response_args = {"value": args["reverb"]}
            elif "delay" in args:
                action_key = "delay"
                track["delay"] = args["delay"]
                response_args = {"value": args["delay"]}
            else:
                return fallback_node(state, history)
            break
            
    action = f"set_{action_key}"
    new_state["response"] = {"action": action, "track_id": track_id, **response_args}
    history.commit(new_state, state.get("history_node_id"))
    return new_state

def toggle_playback_node(state: AgentState, history: HistoryManager):
    print("Executing toggle_playback_node")
    args = state.get("modification_args")
    if not args or "track_id" not in args: return fallback_node(state, history)
    
    new_state = state.copy()
    new_state["tracks"] = [t.copy() for t in state["tracks"]]
    track_id = args["track_id"]
    action = ""
    volume_for_unmute = 1.0

    for track in new_state["tracks"]:
        if track["id"] == track_id:
            track["is_playing"] = not track["is_playing"]
            action = "unmute_track" if track["is_playing"] else "mute_track"
            volume_for_unmute = track["volume"]
            break
            
    new_state["response"] = {"action": action, "track_id": track_id, "volume": volume_for_unmute}
    history.commit(new_state, state.get("history_node_id"))
    return new_state

def undo_node(state: AgentState, history: HistoryManager):
    print("Executing undo_node")
    current_node_id = state.get("history_node_id")
    parent_id = history.get_parent_id(current_node_id) if current_node_id else None
    
    if not parent_id:
        state["response"] = {"speak": "You are at the beginning of the history."}
        return state
        
    reverted_state = history.get_state(parent_id)
    if not reverted_state:
        state["response"] = {"speak": "I could not find the previous state to restore."}
        return state

    state_payload = reverted_state.copy()
    if "response" in state_payload: del state_payload["response"]
    reverted_state["response"] = {"action": "load_state", "state": state_payload}
    return reverted_state

def fallback_node(state: AgentState, history: HistoryManager):
    state["response"] = {"speak": "I'm not sure how to do that."}
    return state
    
# --- LLM Router and Tools ---

@tool
def record():
    """Call this to start recording a new audio loop."""
    pass

@tool
def stop_recording():
    """Call this to stop recording and save the loop."""
    pass

@tool
def undo():
    """Undo the most recent action, reverting the session to its previous state."""
    pass

@tool
def modify_track_volume(track_id: str = Field(..., description="The ID of the track to modify, e.g., 'track_0'."), volume: float = Field(..., description="The new volume level, from 0.0 to 1.0.")):
    """Change the volume of a specific track."""
    pass

@tool
def modify_track_reverb(track_id: str = Field(..., description="The ID of the track to modify, e.g., 'track_0'."), reverb: float = Field(..., description="The new reverb level, from 0.0 to 100.0.")):
    """Apply a reverb effect to a specific track."""
    pass

@tool
def modify_track_delay(track_id: str = Field(..., description="The ID of the track to modify, e.g., 'track_0'."), delay: float = Field(..., description="The new delay level, from 0.0 to 100.0.")):
    """Apply a delay effect to a specific track."""
    pass

@tool
def toggle_track_playback(track_id: str = Field(..., description="The ID of the track to mute or unmute, e.g., 'track_0'.")):
    """Mute or unmute a specific track."""
    pass

@tool
def generate_new_music(prompt: str = Field(..., description="A description of the music to generate, e.g., 'a funky bassline'.")):
    """Generate a new musical piece using AI."""
    pass

@tool
def get_creative_suggestion():
    """Get a creative suggestion for what to add to the current session."""
    pass

tools = [record, stop_recording, undo, modify_track_volume, modify_track_reverb, modify_track_delay, toggle_track_playback, generate_new_music, get_creative_suggestion]
llm = ChatOpenAI(model="gpt-4o", temperature=0)
llm_with_tools = llm.bind_tools(tools)

def router_node(state: AgentState) -> dict:
    """
    This node is the new entry point. It uses the LLM to decide which
    tool to use, and it updates the state with the arguments for that tool
    and the name of the next node to run.
    """
    command = state.get("command", "")
    if not command:
        next_node = "no_op_node"
        modification_args = {}
    else:
        tool_calls = llm_with_tools.invoke(command).tool_calls
        if not tool_calls:
            next_node = "fallback_node"
            modification_args = {}
        else:
            first_call = tool_calls[0]
            tool_name = first_call['name']
            modification_args = first_call.get('args', {})
            
            # Map tool names to node names
            if tool_name in ["modify_track_volume", "modify_track_reverb", "modify_track_delay"]:
                next_node = "modify_track_node"
            else:
                next_node = tool_name.replace("_last_action", "") + "_node"
    
    return {
        "modification_args": modification_args,
        "next_node": next_node
    }

def select_next_node(state: AgentState) -> str:
    """This function is used in the conditional edge to route to the next node."""
    return state.get("next_node", "fallback_node")

# --- Graph Construction ---

def create_graph(history_manager: HistoryManager) -> StateGraph:
    graph_builder = StateGraph(AgentState)
    
    node_functions = {
        "record_node": record_node,
        "stop_recording_node": stop_node,
        "undo_node": undo_node,
        "modify_track_node": modify_track_node,
        "toggle_track_playback_node": toggle_playback_node,
        "generate_new_music_node": music_generation_node,
        "get_creative_suggestion_node": analysis_node,
        "no_op_node": no_op_node,
        "fallback_node": fallback_node
    }
    
    # Add all the worker nodes
    for name, func in node_functions.items():
        graph_builder.add_node(name, partial(func, history=history_manager))

    # Add the router and suggestion nodes
    graph_builder.add_node("router", router_node)
    graph_builder.add_node("suggestion_node", suggestion_node)
    
    # The graph starts at the router
    graph_builder.set_entry_point("router")

    # The router runs, updates the state, and then the conditional edge
    # uses the `select_next_node` function to decide where to go next.
    graph_builder.add_conditional_edges(
        "router",
        select_next_node,
        {
            **{name: name for name in node_functions},
            "suggestion_node": "suggestion_node"
        }
    )

    # Define the final edges
    graph_builder.add_edge("get_creative_suggestion_node", "suggestion_node")
    graph_builder.add_edge("suggestion_node", END)
    
    for name in node_functions:
        if name != "get_creative_suggestion_node":
            graph_builder.add_edge(name, END)

    return graph_builder.compile()

# --- FastAPI App ---

history = HistoryManager("project.db")
if history.get_root_node_id() is None:
    history.commit({"tracks": [], "next_track_id": 0}, parent_id=None)

graph = create_graph(history)

class CommandRequest(BaseModel):
    text: str
    history_node_id: Optional[str] = None

app = FastAPI()

@app.post("/command")
async def process_command(req: CommandRequest):
    """
    Handles incoming commands. For time-sensitive actions like 'record' and
    'stop_recording', it bypasses the LangGraph for immediate execution.
    All other commands are routed through the LLM-powered graph.
    """
    node_id = req.history_node_id or history.get_root_node_id()
    initial_state = history.get_state(node_id)
    if not initial_state:
        return {"speak": "Error: Could not load session state."}
    
    initial_state["command"] = req.text
    
    # --- Fast Path for Real-Time Commands ---
    if req.text == "record":
        print("Fast path: Executing record_node directly.")
        final_state = record_node(initial_state, history)
    elif req.text == "stop_recording":
        print("Fast path: Executing stop_node directly.")
        final_state = stop_node(initial_state, history)
    else:
        # --- Default Path for LLM-Routed Commands ---
        print("Default path: Invoking LangGraph.")
        final_state = graph.invoke(initial_state)
    
    response = final_state.get("response", {})
    if "history_node_id" in final_state:
        response["history_node_id"] = final_state["history_node_id"]
    
    print(f"Responding with: {response}")
    return response

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8000)

