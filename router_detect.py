from __future__ import annotations

import logging
import tempfile
import traceback
from pathlib import Path

from fastapi import APIRouter, File, HTTPException, UploadFile

from ml_service import HybridRoadDetector, format_for_flutter


log = logging.getLogger(__name__)
router = APIRouter()
detector = HybridRoadDetector()


@router.get("/health")
async def health() -> dict:
    grounding_dino_loaded = hasattr(detector, "processor") and hasattr(detector, "hf_model")
    yolo_loaded = getattr(detector, "yolo_model", None) is not None
    return {
        "status": "running" if grounding_dino_loaded else "degraded",
        "grounding_dino_loaded": grounding_dino_loaded,
        "yolo_loaded": yolo_loaded,
        "device": detector.device,
    }


@router.post("/detect")
async def detect(image: UploadFile = File(...)) -> dict:
    suffix = Path(image.filename or "upload.jpg").suffix or ".jpg"
    temp_path: Path | None = None

    print(f"[API] Processing image: {image.filename or 'upload.jpg'}")

    try:
        image_bytes = await image.read()
        if not image_bytes:
            print("[API ERROR] Empty image upload.")
            raise HTTPException(status_code=400, detail="empty image upload")

        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as temp_file:
            temp_file.write(image_bytes)
            temp_path = Path(temp_file.name)

        print("[ML] Running inference")
        result = detector.detect(str(temp_path))
        detections = result.get("detections", [])
        print(f"[ML] Detections found: {len(detections)}")
        return format_for_flutter(result)
    except HTTPException:
        raise
    except Exception as error:
        print(f"[API ERROR] {error}")
        print(traceback.format_exc())
        log.error("Detection failed: %s", error)
        log.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail="model inference failed") from error
    finally:
        if temp_path is not None:
            temp_path.unlink(missing_ok=True)
