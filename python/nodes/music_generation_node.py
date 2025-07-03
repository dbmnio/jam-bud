# _implementation/python/nodes/music_generation_node.py
# This file defines the music generation node for the LangGraph agent.
# It uses the Replicate API to generate a new music track.

from dotenv import load_dotenv
# Load environment variables from .env file
load_dotenv()


import os
import shutil
import requests
import replicate
from typing import Dict


# Check for Replicate API token
if not os.environ.get("REPLICATE_API_TOKEN"):
    print("\n\n⚠️ IMPORTANT: Set the REPLICATE_API_TOKEN environment variable to enable music generation.\n\n")

def generate_and_download_music(prompt: str, output_path: str) -> bool:
    """
    Calls the Replicate API to generate music and downloads the output.

    Args:
        prompt (str): The text prompt for the music generation.
        output_path (str): The path to save the downloaded audio file.

    Returns:
        bool: True if generation and download were successful, False otherwise.
    """
    if not os.environ.get("REPLICATE_API_TOKEN"):
        print("Cannot generate music: REPLICATE_API_TOKEN is not set.")
        return False
        
    try:
        print(f"Running Replicate with prompt: {prompt}")
        # Using the specific model version and parameters from the user's working example.
        output_url = replicate.run(
            "meta/musicgen:671ac645ce5e552cc63a54a2bbff63fcf798043055d2dac5fc9e36a837eedcfb",
            input={ 
                "top_k": 250, 
                "top_p": 0, 
                "prompt": prompt, 
                "duration": 8, 
                "temperature": 1, 
                "continuation": False, 
                "model_version": "stereo-large", 
                "output_format": "mp3", 
                "continuation_start": 0, 
                "multi_band_diffusion": False, 
                "normalization_strategy": "peak", 
                "classifier_free_guidance": 3 
            }
        )
        
        if not output_url:
            print("Replicate API did not return an output URL.")
            return False

        print(f"Downloading generated music from: {output_url}")
        response = requests.get(output_url, stream=True)
        response.raise_for_status()  # Raise an exception for bad status codes

        with open(output_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        
        print(f"Successfully saved music to {output_path}")
        return True

    except replicate.exceptions.ReplicateError as e:
        print(f"Replicate API error: {e}")
        return False
    except requests.exceptions.RequestException as e:
        print(f"Failed to download generated music: {e}")
        return False
    except Exception as e:
        print(f"An unexpected error occurred during music generation: {e}")
        return False

def music_generation_node(state: Dict, history) -> Dict:
    """
    A node that calls a music generation service and adds the new track to the state.
    """
    print("Executing music_generation_node")
    new_state = state.copy()
    new_state["tracks"] = [t.copy() for t in state["tracks"]]
    
    # Extract the prompt from the router's arguments, with a fallback.
    args = state.get("modification_args", {})
    generation_prompt = args.get("prompt", "a groovy 4-bar bass line, 120bpm")

    # Define a path for the new audio file. In a real app, this would be in a project folder.
    new_track_filename = f"generated_track_{state['next_track_id']}.mp3" # The model now produces .mp3

    # Call the actual generation and download function
    if generate_and_download_music(generation_prompt, new_track_filename):
        # In a real app, track properties might come from the generation service.
        new_track = {
            "id": f"track_{state['next_track_id']}",
            "name": f"AI Loop {state['next_track_id']}",
            "volume": 1.0,
            "is_playing": True,
            "path": new_track_filename
        }
        new_state["tracks"].append(new_track)
        new_state["next_track_id"] += 1

        new_state["response"] = {
            "action": "add_new_track",
            "track": new_track,
            "speak": f"I've created a new track for you: {new_track['name']}"
        }

        # Commit the new state to history
        parent_node_id = state.get("history_node_id")
        history.commit(new_state, parent_node_id) # The history manager mutates new_state
    else:
        new_state["response"] = {"speak": "I wasn't able to create any music right now. Maybe check if the Replicate API token is set correctly?"}
        # Do not commit a new state if generation fails

    return new_state 