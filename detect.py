#!/usr/bin/env python3
"""
Hybrid detection pipeline

Primary model: Grounding DINO (HuggingFace)
Fallback model: YOLOv8 custom model
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image
import torch

# HuggingFace
from transformers import AutoModelForZeroShotObjectDetection, AutoProcessor

# YOLO fallback
from ultralytics import YOLO

TEXT_PROMPT = "pothole. flooded road. water logging. broken electric pole. drainage issue. road obstruction."
_MODEL_MANAGERS: dict[tuple[str, float], "ModelManager"] = {}


# ----------------------------
# CLI Arguments
# ----------------------------

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Hybrid Road Issue Detection")
    parser.add_argument("--source", required=True, help="Image source")
    parser.add_argument("--conf", type=float, default=0.25)
    return parser.parse_args()


# ----------------------------
# Load Models
# ----------------------------

def load_dino():

    model_id = "IDEA-Research/grounding-dino-base"

    device = "cuda" if torch.cuda.is_available() else "cpu"

    processor = AutoProcessor.from_pretrained(model_id)
    model = AutoModelForZeroShotObjectDetection.from_pretrained(model_id).to(device)

    return processor, model, device


def load_yolo(weights_path):

    model = YOLO(str(weights_path))

    return model


def get_yolo_weights_path() -> Path:
    return Path(__file__).resolve().parent / "models" / "road_damage" / "weights" / "best.pt"


# ----------------------------
# Grounding DINO Detection
# ----------------------------

def detect_dino(image, processor, model, device):

    inputs = processor(images=image, text=TEXT_PROMPT, return_tensors="pt").to(device)

    with torch.no_grad():
        outputs = model(**inputs)

    results = processor.post_process_grounded_object_detection(
        outputs,
        inputs.input_ids,
        box_threshold=0.4,
        text_threshold=0.3,
        target_sizes=[image.size[::-1]],
    )

    return results


# ----------------------------
# YOLO Fallback
# ----------------------------

def detect_yolo(image_path, model, conf):

    results = model.predict(source=image_path, conf=conf)

    return results


def format_dino_detections(dino_results) -> list[dict]:
    detections: list[dict] = []

    if not dino_results:
        return detections

    result = dino_results[0]

    for score, label, box in zip(
        result["scores"],
        result["labels"],
        result["boxes"],
    ):
        detections.append(
            {
                "label": str(label),
                "confidence": float(score),
                "bbox": [round(float(v), 2) for v in box.tolist()],
            }
        )

    return detections


def format_yolo_detections(yolo_results) -> list[dict]:
    detections: list[dict] = []

    for result in yolo_results:
        boxes = result.boxes

        if boxes is None:
            continue

        names = result.names if hasattr(result, "names") else {}

        for i in range(len(boxes)):
            cls_id = int(boxes.cls[i].item())
            confidence = float(boxes.conf[i].item())
            xyxy = [round(float(v), 2) for v in boxes.xyxy[i].tolist()]
            label = names.get(cls_id, str(cls_id)) if isinstance(names, dict) else str(cls_id)

            detections.append(
                {
                    "label": str(label),
                    "confidence": confidence,
                    "bbox": xyxy,
                }
            )

    return detections


class ModelManager:
    def __init__(self, weights_path: str, conf: float = 0.25) -> None:
        self.weights_path = Path(weights_path)
        self.conf = conf
        self.processor, self.dino_model, self.device = load_dino()
        self.yolo_model = load_yolo(self.weights_path)

    def detect(self, image_path: str) -> dict:
        print("[INFO] Running Grounding DINO (primary model)...")

        image = Image.open(image_path)
        dino_results = detect_dino(image, self.processor, self.dino_model, self.device)

        if len(dino_results) > 0 and len(dino_results[0]["scores"]) > 0:
            score = float(dino_results[0]["scores"][0])

            if score > 0.5:
                return {
                    "source": "grounding_dino",
                    "detections": format_dino_detections(dino_results),
                }

        print("[INFO] DINO detection weak -> using YOLO fallback")

        yolo_results = detect_yolo(image_path, self.yolo_model, self.conf)

        return {
            "source": "fallback_yolo",
            "detections": format_yolo_detections(yolo_results),
        }


def get_model_manager(weights_path: str, conf: float = 0.25) -> ModelManager:
    cache_key = (str(Path(weights_path).resolve()), conf)

    if cache_key not in _MODEL_MANAGERS:
        _MODEL_MANAGERS[cache_key] = ModelManager(weights_path=weights_path, conf=conf)

    return _MODEL_MANAGERS[cache_key]


# ----------------------------
# Hybrid Pipeline
# ----------------------------

def run_pipeline(image_path: str, weights_path: str, conf: float = 0.25) -> dict:
    manager = get_model_manager(weights_path=weights_path, conf=conf)
    return manager.detect(image_path)


# ----------------------------
# Main
# ----------------------------

def main() -> int:

    args = parse_args()

    weights = get_yolo_weights_path()

    if not weights.exists():
        expected_root = weights.parent
        print("[ERROR] YOLO fallback weights not found.")
        print(f"[ERROR] Expected file: {weights}")
        print("[ERROR] Expected folder structure:")
        print(f"{expected_root.parent.parent}/")
        print("  models/")
        print("    road_damage/")
        print("      weights/")
        print("        best.pt")
        return 1

    source = Path(args.source)

    if not source.exists():
        print(f"[ERROR] Source not found: {source}")
        return 1

    results = run_pipeline(str(source), str(weights), args.conf)
    print(json.dumps(results, indent=2))

    return 0


if __name__ == "__main__":
    sys.exit(main())
