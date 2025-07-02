from fastapi import FastAPI
from pydantic import BaseModel
import uvicorn

# A simple dictionary to hold the agent's state.
# For Phase 1, we only need to know if we are currently recording.
agent_state = {
    "is_recording": False
}

# Define the data model for the request body
class Command(BaseModel):
    text: str

# Create a FastAPI instance
app = FastAPI()

# Define the /command endpoint
@app.post("/command")
async def process_command(command: Command):
    """
    Receives a command from the front-end, determines the correct action
    based on simple logic, updates the state, and returns the action.
    """
    print(f"Received command: {command.text}")
    
    action_to_take = "none"
    
    # Simple router logic based on command text
    if command.text.lower() == "record":
        if not agent_state["is_recording"]:
            action_to_take = "start_recording"
            agent_state["is_recording"] = True
    elif command.text.lower() == "stop":
        if agent_state["is_recording"]:
            action_to_take = "stop_recording"
            agent_state["is_recording"] = False
            
    print(f"Responding with action: {action_to_take}")
    
    return {"action": action_to_take, "status": "success"}

# To run this server, use the command:
# uvicorn main:app --host 127.0.0.1 --port 8000 