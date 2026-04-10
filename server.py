import asyncio
import os
import shutil
from pathlib import Path
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Dict, Any, Optional

# Import the main detection function from the existing ml_service
from ml_service import detect_road_issues

app = FastAPI(title="UrbanFlow AI Engine")

# Add CORS middleware to allow requests from the frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins for local development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

BASE_DIR = Path(__file__).resolve().parent
IMAGE_PATH = BASE_DIR / "image.jpg"

@app.post("/detect")
async def detect_image(image: UploadFile = File(...)):
    """
    Receives an image upload from the frontend, saves it locally,
    runs the ML pipeline using ml_service.py, and returns the response.
    """
    if not image.filename:
        raise HTTPException(status_code=400, detail="No file uploaded")
        
    try:
        # Save the uploaded file to 'image.jpg' in the backend directory
        # This matches the expected workflow of the original python scripts
        with open(IMAGE_PATH, "wb") as buffer:
            shutil.copyfileobj(image.file, buffer)
            
        print(f"Image saved to {IMAGE_PATH}")
        
    except Exception as e:
        print(f"Error saving file: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to save image: {str(e)}")

    try:
        # Run the detection in a separate thread to prevent blocking the event loop
        # For simplicity, we can do it directly. In heavy production, use asyncio.to_thread
        result = await asyncio.to_thread(detect_road_issues, str(IMAGE_PATH))
        
        # Log basic success
        print(f"Detection successful. Priority: {result.get('priority', 'UNKNOWN')}")
        
        # Return the exact JSON structure the frontend expects
        return result
        
    except Exception as e:
        print(f"ML Pipeline Error: {e}")
        raise HTTPException(status_code=500, detail=f"Inference failed: {str(e)}")

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "UrbanFlow ML Pipeline"}
