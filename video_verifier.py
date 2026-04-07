#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import tempfile
from pathlib import Path

import cv2

from ml_service import HybridRoadDetector


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Verify road repair status from a video")
    parser.add_argument("--video", required=True, help="Path to repair video")
    return parser.parse_args()


def extract_frames(video_path: Path, output_dir: Path, num_frames: int = 5) -> list[Path]:
    capture = cv2.VideoCapture(str(video_path))
    if not capture.isOpened():
        raise ValueError("Could not open video file.")

    try:
        total_frames = int(capture.get(cv2.CAP_PROP_FRAME_COUNT))
        if total_frames <= 0:
            raise ValueError("Video has no readable frames.")

        target_count = min(num_frames, total_frames)
        frame_indices = sorted({int(index * total_frames / target_count) for index in range(target_count)})
        saved_frames: list[Path] = []

        for index, frame_number in enumerate(frame_indices):
            capture.set(cv2.CAP_PROP_POS_FRAMES, frame_number)
            success, frame = capture.read()
            if not success:
                continue

            frame_path = output_dir / f"frame_{index}.jpg"
            if cv2.imwrite(str(frame_path), frame):
                saved_frames.append(frame_path)

        if not saved_frames:
            raise ValueError("Could not extract frames from video.")

        return saved_frames
    finally:
        capture.release()


def verify_video(video_path: str, detector: HybridRoadDetector | None = None) -> dict:
    detector = detector or HybridRoadDetector()
    input_path = Path(video_path)

    if not input_path.exists():
        raise FileNotFoundError(f"Video not found: {input_path}")

    with tempfile.TemporaryDirectory() as frames_dir:
        frame_paths = extract_frames(input_path, Path(frames_dir), num_frames=5)

        for frame_path in frame_paths:
            result = detector.detect(str(frame_path))
            for detection in result.get("detections", []):
                label = str(detection.get("label", "")).strip().lower().rstrip(".")
                if label == "pothole":
                    return {"repair_status": "failed"}

    return {"repair_status": "verified"}


def main() -> int:
    args = parse_args()

    try:
        result = verify_video(args.video)
    except Exception as error:
        print(f"[ERROR] {error}")
        return 1

    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
