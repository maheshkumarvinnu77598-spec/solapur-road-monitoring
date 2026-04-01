from __future__ import annotations

import tempfile
from pathlib import Path

import cv2
from fastapi import FastAPI, File, HTTPException, UploadFile
import uvicorn

from detect import ModelManager, get_model_manager, get_yolo_weights_path

app = FastAPI(title="Road Damage Detection API")
model_manager: ModelManager | None = None


def extract_frames(video_path: Path, output_dir: Path, num_frames: int = 5) -> list[Path]:
    capture = cv2.VideoCapture(str(video_path))
    if not capture.isOpened():
        raise ValueError("Could not open uploaded video.")

    try:
        total_frames = int(capture.get(cv2.CAP_PROP_FRAME_COUNT))
        if total_frames <= 0:
            raise ValueError("Uploaded video has no readable frames.")

        target_count = min(num_frames, total_frames)
        frame_indices = sorted({int(i * total_frames / target_count) for i in range(target_count)})
        saved_frames: list[Path] = []

        for index, frame_number in enumerate(frame_indices):
            capture.set(cv2.CAP_PROP_POS_FRAMES, frame_number)
            success, frame = capture.read()
            if not success:
                continue

            frame_path = output_dir / f"frame_{index}.jpg"
            if cv2.imwrite(str(frame_path), frame):
                saved_frames.append(frame_path)

        if not saved_frames:
            raise ValueError("Could not extract frames from uploaded video.")

        return saved_frames
    finally:
        capture.release()


@app.on_event("startup")
def load_models() -> None:
    global model_manager

    weights_path = get_yolo_weights_path()
    if not weights_path.exists():
        raise RuntimeError(f"YOLO fallback weights not found. Expected: {weights_path}")

    model_manager = get_model_manager(str(weights_path))


@app.post("/detect")
async def detect(image: UploadFile = File(...)) -> dict:
    suffix = Path(image.filename or "upload.jpg").suffix or ".jpg"

    temp_path: Path | None = None

    try:
        if model_manager is None:
            raise HTTPException(status_code=500, detail="Model manager is not initialized.")

        image_bytes = await image.read()
        if not image_bytes:
            raise HTTPException(status_code=400, detail="Empty image upload.")

        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as temp_file:
            temp_file.write(image_bytes)
            temp_path = Path(temp_file.name)

        return model_manager.detect(str(temp_path))
    except HTTPException:
        raise
    except Exception as error:
        raise HTTPException(status_code=500, detail=str(error)) from error
    finally:
        if temp_path is not None:
            temp_path.unlink(missing_ok=True)


@app.post("/verify-video")
async def verify_video(video: UploadFile = File(...)) -> dict:
    suffix = Path(video.filename or "upload.mp4").suffix or ".mp4"

    temp_video_path: Path | None = None

    try:
        if model_manager is None:
            raise HTTPException(status_code=500, detail="Model manager is not initialized.")

        video_bytes = await video.read()
        if not video_bytes:
            raise HTTPException(status_code=400, detail="Empty video upload.")

        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as temp_file:
            temp_file.write(video_bytes)
            temp_video_path = Path(temp_file.name)

        with tempfile.TemporaryDirectory() as frames_dir:
            frame_paths = extract_frames(temp_video_path, Path(frames_dir), num_frames=5)

            for frame_path in frame_paths:
                result = model_manager.detect(str(frame_path))
                for detection in result.get("detections", []):
                    label = str(detection.get("label", "")).strip().lower().rstrip(".")
                    if label == "pothole":
                        return {"repair_status": "failed"}

        return {"repair_status": "verified"}
    except HTTPException:
        raise
    except Exception as error:
        raise HTTPException(status_code=500, detail=str(error)) from error
    finally:
        if temp_video_path is not None:
            temp_video_path.unlink(missing_ok=True)


if __name__ == "__main__":
    uvicorn.run("api_server:app", host="0.0.0.0", port=8000, reload=True)
