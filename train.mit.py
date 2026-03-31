#!/usr/bin/env python3
"""Train YOLOv8 model for pothole/road-damage detection.

Usage:
  python train.mit.py --data data.yaml --epochs 100
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Train YOLOv8 for Solapur Road Monitoring")
    parser.add_argument("--data", default="data.yaml", help="Path to data.yaml")
    parser.add_argument("--model", default="yolov8n.pt", help="Base YOLO model")
    parser.add_argument("--epochs", type=int, default=100)
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument("--batch", type=int, default=16)
    parser.add_argument("--device", default="0", help="CUDA device id or 'cpu'")
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    data_path = Path(args.data)
    if not data_path.exists():
      print(f"[ERROR] data.yaml not found: {data_path}")
      return 1

    try:
        from ultralytics import YOLO  # type: ignore
    except Exception:
        print("[ERROR] ultralytics package is not installed.")
        print("Install with: pip install ultralytics")
        return 1

    print("=== YOLOv8 Training Started ===")
    print(f"Model:  {args.model}")
    print(f"Data:   {data_path}")
    print(f"Epochs: {args.epochs}")
    print(f"Image:  {args.imgsz}")
    print(f"Batch:  {args.batch}")
    print(f"Device: {args.device}")

    model = YOLO(args.model)
    model.train(
        data=str(data_path),
        epochs=args.epochs,
        imgsz=args.imgsz,
        batch=args.batch,
        device=args.device,
        project="models",
        name="road_damage",
        exist_ok=True,
        verbose=True,
    )

    best_path = Path("models/road_damage/weights/best.pt")
    if best_path.exists():
        print(f"\n[OK] Best model: {best_path.resolve()}")
    else:
        print("\n[WARN] Training finished but best.pt not found at expected path.")

    print("=== YOLOv8 Training Finished ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
