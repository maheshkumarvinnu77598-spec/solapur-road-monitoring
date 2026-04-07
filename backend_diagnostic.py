#!/usr/bin/env python3
from __future__ import annotations

import contextlib
import gc
import importlib
import io
import json
import mimetypes
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parent
YOLO_WEIGHTS_PATH = ROOT_DIR / "models" / "road_damage" / "weights" / "best.pt"
TEST_IMAGES_DIR = ROOT_DIR / "test_images"
ROOT_URL = "http://127.0.0.1:8000"
HEALTH_URL = "http://127.0.0.1:8000/health"
DETECT_URL = "http://127.0.0.1:8000/detect"
GROUNDING_DINO_MODEL_ID = "IDEA-Research/grounding-dino-base"
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png"}

os.environ.setdefault("HF_HUB_OFFLINE", "1")
os.environ.setdefault("HF_HUB_DISABLE_PROGRESS_BARS", "1")
os.environ.setdefault("TRANSFORMERS_OFFLINE", "1")

DEPENDENCIES = [
    ("ultralytics", "ultralytics"),
    ("transformers", "transformers"),
    ("torch", "torch"),
    ("opencv-python", "cv2"),
    ("fastapi", "fastapi"),
    ("uvicorn", "uvicorn"),
    ("pillow", "PIL"),
]


def check_dependencies() -> tuple[bool, list[str]]:
    missing: list[str] = []

    for package_name, module_name in DEPENDENCIES:
        try:
            importlib.import_module(module_name)
        except Exception:
            missing.append(package_name)
            print(f"[ERROR] Missing dependency: {package_name}")

    return len(missing) == 0, missing


def check_yolo_weights() -> bool:
    if not YOLO_WEIGHTS_PATH.exists():
        print("[ERROR] YOLO weights not found.")
        return False

    return True


def check_grounding_dino() -> tuple[bool, str | None]:
    try:
        from transformers import AutoModelForZeroShotObjectDetection, AutoProcessor
        import torch

        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            processor = AutoProcessor.from_pretrained(GROUNDING_DINO_MODEL_ID, local_files_only=True)
            model = AutoModelForZeroShotObjectDetection.from_pretrained(
                GROUNDING_DINO_MODEL_ID,
                local_files_only=True,
            )
        device = "cuda" if torch.cuda.is_available() else "cpu"
        model.to(device)

        del processor
        del model
        gc.collect()
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
        return True, None
    except Exception as error:
        return False, f"Grounding DINO load failed: {error}"


def get_test_image() -> Path | None:
    if not TEST_IMAGES_DIR.exists():
        return None

    for path in sorted(TEST_IMAGES_DIR.iterdir()):
        if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS:
            return path

    return None


def check_local_pipeline(image_path: Path) -> tuple[bool, str | None]:
    try:
        from ml_service import HybridRoadDetector

        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            detector = HybridRoadDetector(weights_path=str(YOLO_WEIGHTS_PATH))
            result = detector.detect(str(image_path))

        if not isinstance(result, dict):
            return False, "Local pipeline returned an invalid response."
        if "detections" not in result:
            return False, "Local pipeline response is missing 'detections'."
        return True, None
    except Exception as error:
        return False, f"Local ML pipeline failed: {error}"


def fetch_json(url: str, timeout: int = 15) -> tuple[int, dict]:
    request = urllib.request.Request(url=url, method="GET")
    with urllib.request.urlopen(request, timeout=timeout) as response:
        payload = response.read().decode("utf-8")
        return response.status, json.loads(payload)


def is_backend_reachable() -> bool:
    try:
        request = urllib.request.Request(url=ROOT_URL, method="GET")
        with urllib.request.urlopen(request, timeout=5) as response:
            return response.status == 200
    except Exception:
        return False


def start_backend() -> tuple[bool, str | None]:
    run_backend_path = ROOT_DIR / "run_backend.py"
    if not run_backend_path.exists():
        return False, "Backend launcher not found: run_backend.py"

    creationflags = 0
    if os.name == "nt":
        creationflags = getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0)

    try:
        env = os.environ.copy()
        env["BACKEND_RELOAD"] = "0"
        subprocess.Popen(
            [sys.executable, str(run_backend_path)],
            cwd=str(ROOT_DIR),
            env=env,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            creationflags=creationflags,
        )
        return True, None
    except Exception as error:
        return False, f"Failed to start backend: {error}"


def ensure_backend_running(timeout_seconds: int = 90) -> tuple[bool, str | None]:
    if is_backend_reachable():
        return True, None

    print("[INFO] Backend is not running. Starting backend with: python run_backend.py")
    started, start_error = start_backend()
    if not started:
        return False, start_error

    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        if is_backend_reachable():
            return True, None
        time.sleep(2)

    return False, "Backend did not respond in time after starting run_backend.py"


def build_multipart_body(field_name: str, file_path: Path) -> tuple[bytes, str]:
    boundary = f"----BackendDiagnostic{uuid.uuid4().hex}"
    content_type = mimetypes.guess_type(file_path.name)[0] or "application/octet-stream"
    file_bytes = file_path.read_bytes()

    parts = [
        f"--{boundary}\r\n".encode("utf-8"),
        (
            f'Content-Disposition: form-data; name="{field_name}"; '
            f'filename="{file_path.name}"\r\n'
        ).encode("utf-8"),
        f"Content-Type: {content_type}\r\n\r\n".encode("utf-8"),
        file_bytes,
        b"\r\n",
        f"--{boundary}--\r\n".encode("utf-8"),
    ]
    return b"".join(parts), boundary


def post_test_image(image_path: Path, timeout: int = 120) -> tuple[int, dict]:
    body, boundary = build_multipart_body("image", image_path)
    request = urllib.request.Request(
        url=DETECT_URL,
        data=body,
        method="POST",
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
    )

    with urllib.request.urlopen(request, timeout=timeout) as response:
        payload = response.read().decode("utf-8")
        return response.status, json.loads(payload)


def check_api_server() -> tuple[bool, dict | None, str | None]:
    try:
        status, payload = fetch_json(HEALTH_URL)
        if status != 200:
            return False, None, f"/health returned HTTP {status}"
        if not isinstance(payload, dict):
            return False, None, "/health returned invalid JSON."
        return True, payload, None
    except urllib.error.URLError:
        return False, None, "API server is not reachable at http://127.0.0.1:8000."
    except Exception as error:
        return False, None, f"Health check failed: {error}"


def check_detection_api(image_path: Path) -> tuple[bool, str | None]:
    try:
        status, payload = post_test_image(image_path)
        if status != 200:
            return False, f"/detect returned HTTP {status}"
        if not isinstance(payload, dict):
            return False, "/detect returned invalid JSON."
        if "issue" not in payload:
            return False, "/detect response is missing 'issue'."
        if "boxes" not in payload:
            return False, "/detect response is missing 'boxes'."
        return True, None
    except urllib.error.HTTPError as error:
        try:
            error_body = error.read().decode("utf-8")
        except Exception:
            error_body = str(error)
        return False, f"Detection API failed: HTTP {error.code} {error_body}"
    except urllib.error.URLError:
        return False, (
            "Detection API is not reachable at http://127.0.0.1:8000/detect. "
            "Start it with: python run_backend.py"
        )
    except Exception as error:
        return False, f"Detection API failed: {error}"


def print_summary(statuses: dict[str, bool]) -> None:
    print("\n=== SYSTEM STATUS ===")
    print(f"Backend server: {'OK' if statuses['backend_server'] else 'FAILED'}")
    print(f"Grounding DINO: {'OK' if statuses['grounding_dino'] else 'FAILED'}")
    print(f"YOLO fallback: {'OK' if statuses['yolo_fallback'] else 'FAILED'}")
    print(f"Inference API: {'OK' if statuses['inference_api'] else 'FAILED'}")


def main() -> int:
    statuses = {
        "backend_server": False,
        "grounding_dino": False,
        "yolo_fallback": False,
        "inference_api": False,
    }

    dependencies_ok, _missing = check_dependencies()

    if not dependencies_ok:
        print_summary(statuses)
        return 1

    if not check_yolo_weights():
        print_summary(statuses)
        return 1

    grounding_ok, grounding_error = check_grounding_dino()
    if grounding_error:
        print(f"[ERROR] {grounding_error}")

    test_image = get_test_image()
    if test_image is None:
        print("[ERROR] No test image found in test_images/")
        print_summary(statuses)
        return 1

    backend_ok, backend_error = ensure_backend_running()
    statuses["backend_server"] = backend_ok
    if backend_error:
        print(f"[ERROR] {backend_error}")
        print_summary(statuses)
        return 1

    api_server_ok, health_payload, api_server_error = check_api_server()
    if api_server_error:
        print(f"[ERROR] {api_server_error}")
        print_summary(statuses)
        return 1

    statuses["backend_server"] = api_server_ok
    statuses["grounding_dino"] = bool(grounding_ok and health_payload and health_payload.get("grounding_dino_loaded"))
    statuses["yolo_fallback"] = bool(health_payload and health_payload.get("yolo_loaded"))

    api_detection_ok, api_detection_error = check_detection_api(test_image)
    statuses["inference_api"] = api_detection_ok
    if api_detection_error:
        print(f"[ERROR] {api_detection_error}")

    print_summary(statuses)
    return 0 if all(statuses.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
