#!/usr/bin/env python3
"""Run inference using trained YOLOv8 weights.

Usage:
  python ai/detect.py --weights models/road_damage/weights/best.pt --source test_images/pothole.jpg
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="YOLOv8 pothole inference")
    parser.add_argument("--weights", required=True, help="Path to best.pt")
    parser.add_argument("--source", required=True, help="Image/video/folder source")
    parser.add_argument("--conf", type=float, default=0.25, help="Confidence threshold")
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument("--save_dir", default="runs/predict")
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    weights = Path(args.weights)
    if not weights.exists():
        print(f"[ERROR] Weights not found: {weights}")
        return 1

    try:
        from ultralytics import YOLO  # type: ignore
    except Exception:
        print("[ERROR] ultralytics package is not installed.")
        print("Install with: pip install ultralytics")
        return 1

    model = YOLO(str(weights))
    results = model.predict(
        source=args.source,
        conf=args.conf,
        imgsz=args.imgsz,
        save=True,
        project=args.save_dir,
        name="road_damage",
        exist_ok=True,
    )

    print("=== Inference Summary ===")
    for i, result in enumerate(results, start=1):
        boxes = result.boxes
        count = 0 if boxes is None else len(boxes)
        print(f"Image {i}: detections={count}")
        if boxes is not None:
            for j in range(len(boxes)):
                cls_id = int(boxes.cls[j].item())
                conf = float(boxes.conf[j].item())
                xyxy = boxes.xyxy[j].tolist()
                print(
                    f"  - box#{j+1} cls={cls_id} conf={conf:.4f} xyxy={[round(v,2) for v in xyxy]}"
                )

    print("Annotated output saved under:")
    print(f"  {Path(args.save_dir) / 'road_damage'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
