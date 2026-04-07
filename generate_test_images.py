#!/usr/bin/env python3
from __future__ import annotations

import random
from pathlib import Path

import requests

OUTPUT_DIR = Path("test_images")
KEYWORDS = ["road", "pothole", "street", "asphalt", "highway"]
HEADERS = {
    "User-Agent": "solapur_road_monitoring/1.0",
}

IMAGE_URLS_BY_KEYWORD = {
    "road": [
        "https://images.unsplash.com/photo-1500375592092-40eb2168fd21?auto=format&fit=crop&w=800&h=600&q=80",
        "https://images.unsplash.com/photo-1473445361085-b9a07f55608b?auto=format&fit=crop&w=800&h=600&q=80",
    ],
    "pothole": [
        "https://images.unsplash.com/photo-1516321497487-e288fb19713f?auto=format&fit=crop&w=800&h=600&q=80",
        "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=800&h=600&q=80",
    ],
    "street": [
        "https://images.unsplash.com/photo-1465447142348-e9952c393450?auto=format&fit=crop&w=800&h=600&q=80",
        "https://images.unsplash.com/photo-1449824913935-59a10b8d2000?auto=format&fit=crop&w=800&h=600&q=80",
    ],
    "asphalt": [
        "https://images.unsplash.com/photo-1507608869274-d3177c8bb4c7?auto=format&fit=crop&w=800&h=600&q=80",
        "https://images.unsplash.com/photo-1480714378408-67cf0d13bc1f?auto=format&fit=crop&w=800&h=600&q=80",
    ],
    "highway": [
        "https://images.unsplash.com/photo-1504384308090-c894fdcc538d?auto=format&fit=crop&w=800&h=600&q=80",
        "https://images.unsplash.com/photo-1500534623283-312aade485b7?auto=format&fit=crop&w=800&h=600&q=80",
    ],
}


def download_image(url: str, output_path: Path) -> None:
    with requests.get(url, stream=True, timeout=60, headers=HEADERS) as response:
        response.raise_for_status()

        with output_path.open("wb") as file_handle:
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    file_handle.write(chunk)


def main() -> int:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    for index in range(1, 11):
        keyword = random.choice(KEYWORDS)
        image_url = random.choice(IMAGE_URLS_BY_KEYWORD[keyword])
        output_path = OUTPUT_DIR / f"road_{index}.jpg"

        print(f"Downloading {output_path.name}")

        try:
            download_image(image_url, output_path)
            print(f"Saved {output_path.name}")
        except requests.RequestException as error:
            print(f"[ERROR] Failed to download {output_path.name}: {error}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
