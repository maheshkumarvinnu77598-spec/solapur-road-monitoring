#!/usr/bin/env python3
"""
Install dependency before running:
    pip install inference-sdk

Usage:
    1. Set the ROBOFLOW_API_KEY environment variable.
    2. Place `image.jpg` in the project folder.
    3. Run: python detect.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from ml_service import detect_road_issues


IMAGE_PATH = Path(__file__).resolve().parent / "image.jpg"


def main() -> int:
    # 1. Ensure the local test image exists in the project folder.
    if not IMAGE_PATH.exists():
        print(f"[ERROR] Image not found: {IMAGE_PATH}")
        return 1

    try:
        # 2. Run the same trained Roboflow workflow pipeline used by the backend.
        result = detect_road_issues(str(IMAGE_PATH))

        # 3. Print the merged, deduplicated JSON response in the terminal.
        print(json.dumps(result, indent=2))
        return 0
    except Exception as error:
        print(f"[ERROR] {error}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
