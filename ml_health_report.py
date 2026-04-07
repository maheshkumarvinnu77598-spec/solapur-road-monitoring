#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import time
import urllib.error
import urllib.request
from pathlib import Path

os.environ.setdefault("HF_HUB_OFFLINE", "1")
os.environ.setdefault("HF_HUB_DISABLE_PROGRESS_BARS", "1")
os.environ.setdefault("TRANSFORMERS_OFFLINE", "1")

from detect import get_yolo_weights_path
from ml_service import HybridRoadDetector


ROOT_DIR = Path(__file__).resolve().parent
TEST_IMAGES_DIR = ROOT_DIR / "test_images"
REPORT_PATH = ROOT_DIR / "runs" / "ml_health_report.json"
HEALTH_URL = "http://127.0.0.1:8000/health"
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png"}


def get_test_images(limit: int = 3) -> list[Path]:
    if not TEST_IMAGES_DIR.exists():
        return []

    return sorted(
        path
        for path in TEST_IMAGES_DIR.iterdir()
        if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS
    )[:limit]


def fetch_api_health() -> dict:
    try:
        request = urllib.request.Request(url=HEALTH_URL, method="GET")
        with urllib.request.urlopen(request, timeout=10) as response:
            payload = json.loads(response.read().decode("utf-8"))
            if not isinstance(payload, dict):
                raise ValueError("Invalid health response")
            payload.setdefault("api_status", payload.get("status", "running"))
            return payload
    except Exception:
        return {
            "api_status": "not_running",
            "grounding_dino_loaded": False,
            "yolo_loaded": False,
        }


def measure_inference(detector: HybridRoadDetector, image_paths: list[Path]) -> float | None:
    if not image_paths:
        return None

    # Warm up the pipeline once so the reported average reflects steady-state inference.
    detector.detect(str(image_paths[0]))

    timings: list[float] = []
    for image_path in image_paths:
        start_time = time.perf_counter()
        detector.detect(str(image_path))
        elapsed_ms = (time.perf_counter() - start_time) * 1000
        timings.append(elapsed_ms)

    return round(sum(timings) / len(timings), 2)


def main() -> int:
    api_health = fetch_api_health()
    weights_path = get_yolo_weights_path()

    grounding_dino_loaded = False
    yolo_loaded = False
    avg_inference_time_ms: float | None = None

    if weights_path.exists():
        try:
            detector = HybridRoadDetector(weights_path=str(weights_path))
            grounding_dino_loaded = hasattr(detector, "processor") and hasattr(detector, "hf_model")
            yolo_loaded = hasattr(detector, "yolo_model")
            avg_inference_time_ms = measure_inference(detector, get_test_images())
        except Exception:
            grounding_dino_loaded = False
            yolo_loaded = False

    report = {
        "api_status": api_health.get("api_status", "not_running"),
        "grounding_dino_loaded": bool(
            api_health.get("grounding_dino_loaded", False) or grounding_dino_loaded
        ),
        "yolo_loaded": bool(api_health.get("yolo_loaded", False) or yolo_loaded),
        "avg_inference_time_ms": avg_inference_time_ms,
    }

    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps(report, indent=2), encoding="utf-8")

    print(json.dumps(report, indent=2))
    print(f"[INFO] Saved health report to: {REPORT_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
