#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from datetime import datetime
from pathlib import Path

REPORTS_DIR = Path("reports")


def build_report(detection_json: dict) -> dict:
    detections = detection_json.get("detections", [])
    first_detection = detections[0] if detections else {}

    return {
        "issue_type": first_detection.get("label", "unknown"),
        "severity": first_detection.get("severity", "unknown"),
        "status": "pending",
        "timestamp": datetime.now().isoformat(timespec="seconds"),
    }


def get_next_report_path() -> Path:
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    existing_reports = sorted(REPORTS_DIR.glob("report_*.json"))
    next_index = len(existing_reports) + 1
    return REPORTS_DIR / f"report_{next_index:03d}.json"


def save_report(report: dict, output_path: Path | None = None) -> Path:
    output_path = output_path or get_next_report_path()
    output_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    return output_path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate structured report from detection JSON")
    parser.add_argument("--input", required=True, help="Path to detection JSON file")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    input_path = Path(args.input)

    if not input_path.exists():
        print(f"[ERROR] Detection JSON not found: {input_path}")
        return 1

    detection_json = json.loads(input_path.read_text(encoding="utf-8"))
    report = build_report(detection_json)
    output_path = save_report(report)
    print(f"[INFO] Report saved to: {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
