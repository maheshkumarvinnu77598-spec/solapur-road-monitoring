#!/usr/bin/env python3
from __future__ import annotations

import importlib
import subprocess
import sys


REQUIRED_PACKAGES = [
    ("ultralytics", "ultralytics"),
    ("transformers", "transformers"),
    ("torch", "torch"),
    ("torchvision", "torchvision"),
    ("opencv-python", "cv2"),
    ("fastapi", "fastapi"),
    ("uvicorn", "uvicorn"),
    ("pillow", "PIL"),
    ("requests", "requests"),
]


def is_installed(module_name: str) -> bool:
    try:
        importlib.import_module(module_name)
        return True
    except Exception:
        return False


def install_package(package_name: str) -> bool:
    print(f"[FIX] Installing missing package: {package_name}")
    result = subprocess.run(
        [sys.executable, "-m", "pip", "install", package_name],
        check=False,
    )
    return result.returncode == 0


def main() -> int:
    failed_installs: list[str] = []

    for package_name, module_name in REQUIRED_PACKAGES:
        if is_installed(module_name):
            continue

        if not install_package(package_name):
            failed_installs.append(package_name)

    if failed_installs:
        for package_name in failed_installs:
            print(f"[ERROR] Failed to install package: {package_name}")
        return 1

    print("[FIX] All required dependencies are installed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
