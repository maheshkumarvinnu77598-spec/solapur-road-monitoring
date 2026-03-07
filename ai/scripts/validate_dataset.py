#!/usr/bin/env python3
"""Validate YOLOv8 dataset structure and label-image consistency.

Usage:
  python ai/scripts/validate_dataset.py --dataset dataset --yaml data.yaml
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Iterable

try:
    import yaml  # type: ignore
except Exception:  # pragma: no cover
    yaml = None

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate YOLOv8 dataset")
    parser.add_argument("--dataset", default="dataset", help="Dataset root")
    parser.add_argument("--yaml", default="data.yaml", help="Path to data.yaml")
    return parser.parse_args()


def read_yaml(path: Path) -> dict:
    if yaml is None:
        raise RuntimeError("PyYAML is required. Install with: pip install pyyaml")
    if not path.exists():
        raise FileNotFoundError(f"Missing data.yaml: {path}")
    with path.open("r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}
    if not isinstance(data, dict):
        raise ValueError("data.yaml must parse into a dictionary")
    return data


def list_images(path: Path) -> list[Path]:
    if not path.exists():
        return []
    return [p for p in sorted(path.iterdir()) if p.is_file() and p.suffix.lower() in IMAGE_EXTS]


def list_labels(path: Path) -> list[Path]:
    if not path.exists():
        return []
    return [p for p in sorted(path.iterdir()) if p.is_file() and p.suffix.lower() == ".txt"]


def validate_label_file(label_path: Path, class_count: int) -> tuple[bool, str | None]:
    content = label_path.read_text(encoding="utf-8", errors="ignore").strip()
    if not content:
        return False, "empty"

    for line_no, line in enumerate(content.splitlines(), start=1):
        parts = line.strip().split()
        if len(parts) != 5:
            return False, f"invalid format at line {line_no}"
        try:
            cls = int(float(parts[0]))
            coords = [float(x) for x in parts[1:]]
        except ValueError:
            return False, f"non-numeric value at line {line_no}"
        if cls < 0 or cls >= class_count:
            return False, f"class index out of range at line {line_no}"
        if not all(0.0 <= v <= 1.0 for v in coords):
            return False, f"bbox values out of range at line {line_no}"

    return True, None


def corresponding_label(image_path: Path, labels_dir: Path) -> Path:
    return labels_dir / f"{image_path.stem}.txt"


def corresponding_image(label_path: Path, images_dir: Path) -> Path | None:
    for ext in IMAGE_EXTS:
        candidate = images_dir / f"{label_path.stem}{ext}"
        if candidate.exists():
            return candidate
    return None


def rel_list(paths: Iterable[Path], base: Path) -> list[str]:
    return [str(p.relative_to(base)) for p in paths]


def main() -> int:
    args = parse_args()
    dataset_root = Path(args.dataset).resolve()
    yaml_path = Path(args.yaml).resolve()

    print("=== YOLOv8 Dataset Validation Report ===")
    print(f"Dataset root: {dataset_root}")
    print(f"data.yaml:    {yaml_path}")

    issues: list[str] = []

    required_dirs = [
        dataset_root / "images" / "train",
        dataset_root / "images" / "val",
        dataset_root / "labels" / "train",
        dataset_root / "labels" / "val",
    ]

    for d in required_dirs:
        if not d.exists():
            issues.append(f"Missing required directory: {d}")

    try:
        data_cfg = read_yaml(yaml_path)
    except Exception as exc:
        issues.append(str(exc))
        data_cfg = {}

    if data_cfg:
        for key in ("train", "val", "nc", "names"):
            if key not in data_cfg:
                issues.append(f"data.yaml missing key: {key}")

        if "names" in data_cfg and "nc" in data_cfg:
            names = data_cfg.get("names")
            nc = data_cfg.get("nc")
            if not isinstance(names, list):
                issues.append("data.yaml 'names' must be a list")
            elif not isinstance(nc, int):
                issues.append("data.yaml 'nc' must be an integer")
            elif len(names) != nc:
                issues.append("data.yaml mismatch: len(names) != nc")

        for split_key in ("train", "val"):
            split_val = data_cfg.get(split_key)
            if isinstance(split_val, str):
                split_path = (yaml_path.parent / split_val).resolve()
                if not split_path.exists():
                    issues.append(f"data.yaml path not found for {split_key}: {split_path}")

    class_count = data_cfg.get("nc") if isinstance(data_cfg.get("nc"), int) else 9999

    total_valid_samples = 0
    missing_labels: list[Path] = []
    empty_labels: list[Path] = []
    corrupted_entries: list[str] = []
    labels_without_images: list[Path] = []

    split_image_counts: dict[str, int] = {}

    for split in ("train", "val"):
        images_dir = dataset_root / "images" / split
        labels_dir = dataset_root / "labels" / split

        images = list_images(images_dir)
        labels = list_labels(labels_dir)
        split_image_counts[split] = len(images)

        print(f"\n[{split}] images={len(images)} labels={len(labels)}")

        for img in images:
            lbl = corresponding_label(img, labels_dir)
            if not lbl.exists():
                missing_labels.append(lbl)
                continue

            valid, reason = validate_label_file(lbl, class_count)
            if not valid:
                if reason == "empty":
                    empty_labels.append(lbl)
                else:
                    corrupted_entries.append(f"{lbl}: {reason}")
                continue

            total_valid_samples += 1

        for lbl in labels:
            if corresponding_image(lbl, images_dir) is None:
                labels_without_images.append(lbl)

    if split_image_counts.get("train", 0) == 0:
        issues.append("No training images found in dataset/images/train")
    if split_image_counts.get("val", 0) == 0:
        issues.append("No validation images found in dataset/images/val")

    print("\n--- Summary ---")
    print(f"Valid samples:            {total_valid_samples}")
    print(f"Missing label files:      {len(missing_labels)}")
    print(f"Empty label files:        {len(empty_labels)}")
    print(f"Corrupted label entries:  {len(corrupted_entries)}")
    print(f"Label files w/o images:   {len(labels_without_images)}")

    root = dataset_root.parent if dataset_root.parent.exists() else dataset_root

    if missing_labels:
        print("\nMissing label examples:")
        for item in rel_list(missing_labels[:20], root):
            print(f"  - {item}")

    if empty_labels:
        print("\nEmpty label examples:")
        for item in rel_list(empty_labels[:20], root):
            print(f"  - {item}")

    if corrupted_entries:
        print("\nCorrupted label examples:")
        for item in corrupted_entries[:20]:
            print(f"  - {item}")

    if labels_without_images:
        print("\nLabels without image examples:")
        for item in rel_list(labels_without_images[:20], root):
            print(f"  - {item}")

    if issues:
        print("\nConfiguration issues:")
        for issue in issues:
            print(f"  - {issue}")

    failed = bool(issues or missing_labels or empty_labels or corrupted_entries or labels_without_images)
    if failed:
        print("\nResult: FAILED")
        return 1

    print("\nResult: PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
