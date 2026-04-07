#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

from detect import run_pipeline

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Batch test hybrid road issue detection")
    parser.add_argument("--weights", required=True, help="Path to YOLO best.pt")
    parser.add_argument("--source", required=True, help="Folder containing test images")
    parser.add_argument("--conf", type=float, default=0.25, help="YOLO confidence threshold")
    return parser.parse_args()


def get_image_paths(source_dir: Path) -> list[Path]:
    return sorted(
        path for path in source_dir.iterdir()
        if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS
    )


def main() -> int:
    args = parse_args()

    weights_path = Path(args.weights)
    if not weights_path.exists():
        print(f"[ERROR] Weights not found: {weights_path}")
        return 1

    source_dir = Path(args.source)
    if not source_dir.exists() or not source_dir.is_dir():
        print(f"[ERROR] Source folder not found: {source_dir}")
        return 1

    image_paths = get_image_paths(source_dir)
    if not image_paths:
        print(f"[ERROR] No .jpg, .jpeg, or .png files found in: {source_dir}")
        return 1

    output_dir = Path("runs")
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / "test_results.json"
    metrics_path = output_dir / "ml_metrics.json"

    all_results: list[dict] = []
    metrics = {
        "total_images": len(image_paths),
        "grounding_dino": 0,
        "yolo_fallback": 0,
        "no_detection": 0,
    }

    for image_path in image_paths:
        result = run_pipeline(str(image_path), str(weights_path), args.conf)
        result_with_image = {
            "image": image_path.name,
            "source": result["source"],
            "detections": result["detections"],
        }
        all_results.append(result_with_image)
        print(json.dumps(result_with_image, indent=2))

        if not result["detections"]:
            metrics["no_detection"] += 1
        elif result["source"] == "grounding_dino":
            metrics["grounding_dino"] += 1
        elif result["source"] == "fallback_yolo":
            metrics["yolo_fallback"] += 1

    output_path.write_text(json.dumps(all_results, indent=2), encoding="utf-8")
    metrics_path.write_text(json.dumps(metrics, indent=2), encoding="utf-8")
    print(f"[INFO] Saved batch results to: {output_path}")
    print(f"[INFO] Saved ML metrics to: {metrics_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
