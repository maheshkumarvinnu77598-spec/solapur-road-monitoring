from __future__ import annotations

import time

from fastapi import FastAPI, Request
from starlette.middleware.base import BaseHTTPMiddleware

from router_detect import router as detect_router


class BackendLoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        start_time = time.perf_counter()
        print(f"[REQUEST] {request.method} {request.url.path}")

        try:
            response = await call_next(request)
        except Exception as error:
            print(f"[API ERROR] {error}")
            raise

        print("[API] Response sent successfully")
        elapsed_ms = round((time.perf_counter() - start_time) * 1000, 2)
        print(f"[API] Processing completed in {elapsed_ms} ms")
        return response


app = FastAPI(title="Road Issue Detection API")
app.add_middleware(BackendLoggingMiddleware)
app.include_router(detect_router)


@app.get("/")
def root() -> dict:
    return {
        "status": "ML API running",
        "docs": "/docs",
        "health": "/health",
        "detect_endpoint": "/detect",
    }
