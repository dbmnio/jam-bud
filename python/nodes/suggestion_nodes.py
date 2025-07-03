# _implementation/python/nodes/suggestion_nodes.py
# This file defines the nodes responsible for analyzing the current
# musical state and generating creative suggestions.

from typing import Dict

def analysis_node(state: Dict, history) -> Dict:
    """
    Analyzes the current state and generates a human-readable summary.
    This is a placeholder for a more sophisticated analysis engine.
    """
    print("Executing analysis_node")
    
    track_count = len(state.get("tracks", []))
    
    # Simple, hardcoded summary based on the number of tracks.
    if track_count == 0:
        summary = "The session is currently empty."
    elif track_count == 1:
        summary = "There is currently one loop playing."
    else:
        summary = f"There are {track_count} tracks playing together."
        
    # We add the summary to the state to be passed to the next node.
    state["analysis_summary"] = summary
    return state

def suggestion_node(state: Dict, history) -> Dict:
    """
    Generates a creative suggestion based on the analysis summary.
    This is a placeholder for a real LLM-based suggestion engine.
    """
    print("Executing suggestion_node")
    
    summary = state.get("analysis_summary", "The session is empty.")
    
    # Simple, hardcoded suggestion.
    if "empty" in summary:
        suggestion = "How about starting with a simple drum beat?"
    else:
        suggestion = "A funky bassline might sound cool on top of that."

    # The final response is a spoken suggestion for the user.
    # We do not commit a new state, as this is a read-only operation.
    state["response"] = {"speak": suggestion}
    return state 