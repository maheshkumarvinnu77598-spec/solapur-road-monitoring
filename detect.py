#!/usr/bin/env python3
"""
Install dependency before running:
    pip install inference-sdk

Usage:
    Set the ROBOFLOW_API_KEY environment variable, then run:
    python detect.py
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

from inference_sdk import InferenceHTTPClient


API_URL = "https://serverless.roboflow.com"
WORKSPACE_NAME = "tillu-kowkuntla"
WORKFLOW_ID = "detect-and-classify-2"
IMAGE_PATH = Path("image.jpg")


def main() -> int:
    api_key = os.getenv("ROBOFLOW_API_KEY", "").strip()
    if not api_key:
        print("[ERROR] ROBOFLOW_API_KEY is not set.")
        print("Set it in your terminal before running: python detect.py")
        return 1

    if not IMAGE_PATH.exists():
        print(f"[ERROR] Image not found: {IMAGE_PATH.resolve()}")
        return 1

    # 1. Import the library.
    # Done at the top of the file with `from inference_sdk import InferenceHTTPClient`.

    # 2. Connect to the Roboflow serverless client.
    client = InferenceHTTPClient(
        api_url=API_URL,
        api_key=api_key,
    )

    # 3. Run the workflow on the local image.
    result = client.run_workflow(
        workspace_name=WORKSPACE_NAME,
        workflow_id=WORKFLOW_ID,
        images={
            "image": str(IMAGE_PATH),
        },
        use_cache=True,
    )

    # 4. Print the inference result as formatted JSON.
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
