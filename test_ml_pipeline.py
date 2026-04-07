#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

import requests

API_URL = "http://127.0.0.1:8000/detect"
TEST_IMAGES_DIR = Path("test_images")
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png"}


def get_test_images(limit: int = 3) -> list[Path]:
    return sorted(
        path for path in TEST_IMAGES_DIR.iterdir()
        if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS
    )[:limit]


def main() -> int:
    if not TEST_IMAGES_DIR.exists():
        print(f"[ERROR] Test images folder not found: {TEST_IMAGES_DIR}")
        return 1

    image_paths = get_test_images(limit=3)
    if len(image_paths) < 3:
        print("[ERROR] At least 3 test images are required in test_images/")
        return 1

    successful_detections = 0
    errors = 0

    for image_path in image_paths:
        print(f"Testing {image_path.name}")

        try:
            with image_path.open("rb") as image_file:
                response = requests.post(
                    API_URL,
                    files={"image": (image_path.name, image_file, "image/jpeg")},
                    timeout=120,
                )

            response.raise_for_status()
            result = response.json()

            if result.get("status") == "error":
                print("Error")
                errors += 1
            elif result.get("source") == "fallback_yolo":
                print("Fallback YOLO used")
                successful_detections += 1
            else:
                print("Detection success")
                successful_detections += 1
        except Exception:
            print("Error")
            errors += 1

        print()

    print("=== ML TEST SUMMARY ===")
    print(f"Total tests: {len(image_paths)}")
    print(f"Successful detections: {successful_detections}")
    print(f"Errors: {errors}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
