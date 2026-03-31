from __future__ import annotations

import tempfile
from pathlib import Path

from fastapi import FastAPI, File, HTTPException, UploadFile
from ultralytics import YOLO

app = FastAPI(title="Road Damage Detection API")

ROOT_DIR = Path(__file__).resolve().parent.parent
MODEL_PATH = ROOT_DIR / "models" / "road_damage" / "weights" / "best.pt"
model = YOLO(str(MODEL_PATH))


@app.post("/detect")
async def detect(image: UploadFile = File(...)) -> dict[str, list[dict[str, object]]]:
    suffix = Path(image.filename or "upload.jpg").suffix or ".jpg"

    try:
        image_bytes = await image.read()
        if not image_bytes:
            raise HTTPException(status_code=400, detail="Empty image upload.")

        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as temp_file:
            temp_file.write(image_bytes)
            temp_path = Path(temp_file.name)

        try:
            results = model.predict(source=str(temp_path), save=False, verbose=False)
        finally:
            temp_path.unlink(missing_ok=True)
    except HTTPException:
        raise
    except Exception as error:
        raise HTTPException(status_code=500, detail=str(error)) from error


    detections: list[dict[str, object]] = []
    for result in results:
        boxes = result.boxes
        if boxes is None:
            continue

        names = result.names if isinstance(result.names, dict) else {}
        for index in range(len(boxes)):
            xyxy = boxes.xyxy[index].tolist()
            x1, y1, x2, y2 = [float(value) for value in xyxy]
            class_id = int(boxes.cls[index].item())
            detections.append(
                {
                    "label": names.get(class_id, str(class_id)),
                    "confidence": float(boxes.conf[index].item()),
                    "box": {
                        "x": x1,
                        "y": y1,
                        "width": max(0.0, x2 - x1),
                        "height": max(0.0, y2 - y1),
                    },
                }
            )

    return {"detections": detections}


# Start with:
# uvicorn ai_training_workspace.api:app --host 0.0.0.0 --port 8000 --reload
