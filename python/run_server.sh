#!/bin/bash
# This script activates the virtual environment and starts the FastAPI server.

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

echo "Activating virtual environment..."
source "$SCRIPT_DIR/jamsession3/bin/activate"

echo "Changing to server directory: $SCRIPT_DIR"
cd "$SCRIPT_DIR"

echo "Deleting old project.db. REMOVE when later implementation relies on persistent project.db"
rm $SCRIPT_DIR/project.db

echo "Starting FastAPI server..."
uvicorn main:app --host 127.0.0.1 --port 8000 
