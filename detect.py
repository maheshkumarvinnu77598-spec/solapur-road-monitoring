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

from ml_service import HybridRoadDetector, get_hybrid_detector


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Hybrid Road Issue Detection")
    parser.add_argument("--weights", required=True, help="Path to YOLO best.pt")
    parser.add_argument("--source", required=True, help="Image source")
    parser.add_argument("--conf", type=float, default=0.25)
    return parser.parse_args()


def get_yolo_weights_path() -> Path:
    return Path(__file__).resolve().parent / "models" / "road_damage" / "weights" / "best.pt"


def get_model_manager(weights_path: str, conf: float = 0.25) -> HybridRoadDetector:
    return get_hybrid_detector(weights_path=weights_path, conf=conf)


def run_pipeline(image_path: str, weights_path: str, conf: float = 0.25) -> dict:
    manager = get_model_manager(weights_path=weights_path, conf=conf)
    return manager.detect(image_path)


def main() -> int:
    args = parse_args()

    weights = Path(args.weights)
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
