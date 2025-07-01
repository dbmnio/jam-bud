from fastapi import FastAPI
from pydantic import BaseModel
import uvicorn

# Define the data model for the request body
class Command(BaseModel):
    text: str

# Create a FastAPI instance
app = FastAPI()

# Define the /command endpoint
@app.post("/command")
async def process_command(command: Command):
    """
    Receives a command from the front-end, prints it,
    and returns a simple acknowledgement.
    """
    print(f"Received command: {command.text}")
    return {"action": "none", "status": "received"}

# To run this server, use the command:
# uvicorn main:app --host 127.0.0.1 --port 8000 