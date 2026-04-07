#!/usr/bin/env python3
from __future__ import annotations

import os

import uvicorn


def main() -> int:
    reload_enabled = os.environ.get("BACKEND_RELOAD", "1") != "0"

    print("[BACKEND] Starting ML inference server...")
    print("[BACKEND] Server running at http://127.0.0.1:8000")
    print("[BACKEND] API docs at http://127.0.0.1:8000/docs")

    try:
        uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=reload_enabled)
        return 0
    except Exception as error:
        print(f"[BACKEND ERROR] {error}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
