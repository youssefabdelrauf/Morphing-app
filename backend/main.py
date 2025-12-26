from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from typing import Optional
from face_service import face_service
import os

app = FastAPI(title="Morphy Face API", description="Face morphing API for Morphy app")

# Allow Flutter app to access the API (CORS)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Serve sound files statically
assets_dir = os.path.join(os.path.dirname(__file__), "..", "UI", "assets")
if os.path.exists(assets_dir):
    app.mount("/sounds", StaticFiles(directory=assets_dir), name="sounds")


class ProcessFrameRequest(BaseModel):
    """Request model for frame processing."""
    frame: str  # Base64 encoded image
    asset_id: str
    opacity: Optional[float] = 1.0


class ProcessFrameResponse(BaseModel):
    """Response model for frame processing."""
    success: bool
    frame: Optional[str] = None  # Base64 encoded processed image
    mouth_open: Optional[bool] = None  # Whether mouth is detected as open
    message: Optional[str] = None


@app.get("/")
def root():
    return {"message": "Morphy Face API is running!"}


@app.get("/hello")
def hello():
    return {"message": "Hello from Python! 🐍"}


@app.get("/categories")
def get_categories():
    """Get list of available filter categories."""
    categories = face_service.get_categories()
    return {"categories": categories}


@app.get("/categories/{category}/assets")
def get_category_assets(category: str):
    """Get assets for a specific category."""
    assets = face_service.get_category_assets(category)
    if not assets:
        raise HTTPException(status_code=404, detail=f"Category '{category}' not found or empty")
    return {"category": category, "assets": assets}


@app.post("/process-frame", response_model=ProcessFrameResponse)
def process_frame(request: ProcessFrameRequest):
    """Process a frame with face morphing."""
    try:
        result = face_service.process_frame(
            frame_b64=request.frame,
            asset_id=request.asset_id,
            opacity=request.opacity
        )
        
        if result:
            return ProcessFrameResponse(
                success=True, 
                frame=result.get("frame"),
                mouth_open=result.get("mouth_open", False)
            )
        else:
            return ProcessFrameResponse(success=False, message="Could not process frame")
    except Exception as e:
        return ProcessFrameResponse(success=False, message=str(e))


class GenderDetectRequest(BaseModel):
    """Request model for gender detection."""
    frame: str  # Base64 encoded image


class GenderResponse(BaseModel):
    """Response model for gender detection."""
    gender: str
    confidence: float
    error: Optional[str] = None


@app.post("/detect-gender", response_model=GenderResponse)
def detect_gender(request: GenderDetectRequest):
    """Key endpoint for gender detection."""
    result = face_service.detect_gender(request.frame)
    
    if "error" in result:
        return GenderResponse(gender="Unknown", confidence=0.0, error=result["error"])
        
    return GenderResponse(
        gender=result["gender"],
        confidence=result["confidence"]
    )



class RecordingRequest(BaseModel):
    width: int = 640
    height: int = 480
    fps: int = 20

@app.post("/start-recording")
def start_recording(request: RecordingRequest):
    success = face_service.start_recording(request.width, request.height, request.fps)
    if success:
        return {"success": True, "message": "Recording started"}
    else:
        raise HTTPException(status_code=500, detail="Failed to start recording")

@app.post("/stop-recording")
def stop_recording():
    video_b64 = face_service.stop_recording()
    if video_b64:
        return {"success": True, "video": video_b64}
    else:
        return {"success": False, "message": "No video recorded or error reading file"}
