#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
from pathlib import Path

os.environ.setdefault("HF_HUB_OFFLINE", "1")
os.environ.setdefault("HF_HUB_DISABLE_PROGRESS_BARS", "1")
os.environ.setdefault("TRANSFORMERS_OFFLINE", "1")

from detect import get_yolo_weights_path
from ml_service import HybridRoadDetector

TEST_IMAGES_DIR = Path("test_images")
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Verify the local ML pipeline without the API")
    parser.add_argument("images", nargs="*", help="Optional image paths to test")
    return parser.parse_args()


def get_test_images(explicit_images: list[str]) -> list[Path]:
    if explicit_images:
        return [Path(image) for image in explicit_images]

    if not TEST_IMAGES_DIR.exists():
        return []

    return sorted(
        path
        for path in TEST_IMAGES_DIR.iterdir()
        if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS
    )


def main() -> int:
    args = parse_args()
    weights_path = get_yolo_weights_path()
    if not weights_path.exists():
        print("[ERROR] YOLO weights not found.")
        return 1

    image_paths = get_test_images(args.images)
    if not image_paths:
        print("[ERROR] No test images found.")
        return 1

    try:
        detector = HybridRoadDetector(weights_path=str(weights_path))
    except Exception as error:
        print(f"[ERROR] Failed to load HybridRoadDetector: {error}")
        return 1

    grounding_dino_detections = 0
    yolo_fallback_detections = 0
    errors = 0

    for image_path in image_paths:
        print(f"Testing {image_path.name}")
        if not image_path.exists():
            errors += 1
            print(f"[ERROR] Image not found: {image_path}")
            print()
            continue

        try:
            result = detector.detect(str(image_path))
            detections = result.get("detections", [])
            if detections:
                labels = ", ".join(detection["label"] for detection in detections)
                print(f"Detection success: {labels}")
            else:
                print("Detection success: no detections")

            for detection in detections:
                model_name = str(detection.get("model", ""))
                if model_name == "grounding_dino":
                    grounding_dino_detections += 1
                elif model_name == "yolo":
                    yolo_fallback_detections += 1
        except Exception as error:
            errors += 1
            print(f"[ERROR] {error}")

        print()

    print("=== ML PIPELINE TEST ===")
    print(f"Images tested: {len(image_paths)}")
    print(f"Grounding DINO detections: {grounding_dino_detections}")
    print(f"YOLO fallback detections: {yolo_fallback_detections}")
    print(f"Errors: {errors}")
    return 0 if errors == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
