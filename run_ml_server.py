#!/usr/bin/env python3
from __future__ import annotations

import uvicorn


def main() -> int:
    print("ML server running on http://127.0.0.1:8000")
    uvicorn.run("main:app", host="127.0.0.1", port=8000)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
