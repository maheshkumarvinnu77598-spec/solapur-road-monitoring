#!/usr/bin/env python3
from __future__ import annotations

import os
from pathlib import Path

os.environ.setdefault("HF_HUB_OFFLINE", "1")
os.environ.setdefault("HF_HUB_DISABLE_PROGRESS_BARS", "1")
os.environ.setdefault("TRANSFORMERS_OFFLINE", "1")

from detect import get_yolo_weights_path
from ml_service import HybridRoadDetector

TEST_IMAGES_DIR = Path("test_images")
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png"}


def get_test_images() -> list[Path]:
    if not TEST_IMAGES_DIR.exists():
        return []

    return sorted(
        path
        for path in TEST_IMAGES_DIR.iterdir()
        if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS
    )


def main() -> int:
    weights_path = get_yolo_weights_path()
    if not weights_path.exists():
        print("[ERROR] YOLO weights not found.")
        return 1

    image_paths = get_test_images()
    if not image_paths:
        print("[ERROR] No test images found in test_images/")
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

        try:
            result = detector.detect(str(image_path))

            if result.get("source") == "grounding_dino":
                grounding_dino_detections += 1
            elif result.get("source") == "fallback_yolo":
                yolo_fallback_detections += 1

            print("Detection success")
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
