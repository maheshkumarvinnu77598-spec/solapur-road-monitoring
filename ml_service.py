from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path
import time

from PIL import Image
import torch
from transformers import AutoModelForZeroShotObjectDetection, AutoProcessor
from ultralytics import YOLO

MODEL_ID = "IDEA-Research/grounding-dino-base"
FULL_DINO_LABELS = [
    "pothole",
    "water logging on road",
    "broken streetlight",
    "drainage blockage",
    "road obstruction",
]
SUPPLEMENTAL_DINO_LABELS = [
    "broken streetlight",
    "drainage blockage",
    "road obstruction",
]
YOLO_LABEL_MAP = {
    "pothole": "pothole",
    "water_logging": "water logging on road",
    "road_damage": "road damage",
}
DINO_CONFIDENCE_FLOORS = {
    "pothole": 0.16,
    "water logging on road": 0.16,
    "broken streetlight": 0.20,
    "drainage blockage": 0.16,
    "road obstruction": 0.13,
}
_DETECTORS: dict[tuple[str, float], "HybridRoadDetector"] = {}
DEBUG_LOG_PATH = Path("runs") / "ml_debug_log.json"


def get_default_weights_path() -> Path:
    return Path(__file__).resolve().parent / "models" / "road_damage" / "weights" / "best.pt"


class HybridRoadDetector:
    def __init__(self, weights_path: str | None = None, conf: float = 0.15) -> None:
        self.weights_path = Path(weights_path) if weights_path is not None else get_default_weights_path()
        self.conf = conf
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        self.yolo_model: YOLO | None = None
        print(f"[ML] Running on device: {self.device}")

        try:
            print("[ML] Loading Grounding DINO model...")
            try:
                self.processor = AutoProcessor.from_pretrained(MODEL_ID, local_files_only=True)
                self.hf_model = AutoModelForZeroShotObjectDetection.from_pretrained(
                    MODEL_ID,
                    local_files_only=True,
                ).to(self.device)
                print("[ML] Grounding DINO loaded successfully from local cache")
            except Exception:
                self.processor = AutoProcessor.from_pretrained(MODEL_ID)
                self.hf_model = AutoModelForZeroShotObjectDetection.from_pretrained(MODEL_ID).to(self.device)
                print("[ML] Grounding DINO loaded successfully")
        except Exception as error:
            raise RuntimeError("[ML ERROR] Failed to load Grounding DINO model") from error

        try:
            if self.weights_path.exists():
                print("[ML] Loading YOLO model...")
                self.yolo_model = YOLO(str(self.weights_path))
                print("[ML] YOLO loaded successfully")
                print("[ML DEBUG] YOLO class names:", self.yolo_model.names)
            else:
                print(f"[ML WARNING] YOLO weights not found: {self.weights_path}")
        except Exception as error:
            print(f"[ML WARNING] Failed to load YOLO model: {error}")

    def detect(self, image_path: str) -> dict:
        image_name = Path(image_path).name
        start_time = time.perf_counter()
        print(f"[ML] Running detection on image: {image_name}")

        try:
            image = Image.open(image_path).convert("RGB")
        except Exception as error:
            raise RuntimeError(f"Failed to read image: {error}") from error
        print("[ML] Image size:", image.size)
        yolo_detections = self.detect_with_yolo(image_path)
        dino_labels = SUPPLEMENTAL_DINO_LABELS if yolo_detections else FULL_DINO_LABELS
        dino_detections = self.detect_with_hf(image, dino_labels)
        detections = self.merge_detections(yolo_detections, dino_detections, image.size)
        primary_issue = self.select_primary_issue(detections, image.size)
        if yolo_detections and dino_detections:
            source = "hybrid"
        elif yolo_detections:
            source = "yolo"
        else:
            source = "grounding_dino"
        result = {
            "source": source,
            "primary_issue": primary_issue,
            "detected_classes": [detection["label"] for detection in detections],
            "detections": detections,
        }

        print(f"[ML] Final detections: {len(result['detections'])}")
        print(f"[ML] Total detections: {len(result['detections'])}")
        self.append_debug_log(
            image_name=image_name,
            model_used=result["source"],
            detections_count=len(result["detections"]),
            processing_time_ms=round((time.perf_counter() - start_time) * 1000),
        )
        return result

    @staticmethod
    def append_debug_log(
        image_name: str,
        model_used: str,
        detections_count: int,
        processing_time_ms: int,
    ) -> None:
        DEBUG_LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        log_entry = {
            "image": image_name,
            "model_used": model_used,
            "detections": detections_count,
            "processing_time_ms": processing_time_ms,
            "timestamp": datetime.now().isoformat(timespec="seconds"),
        }

        if DEBUG_LOG_PATH.exists():
            try:
                existing_logs = json.loads(DEBUG_LOG_PATH.read_text(encoding="utf-8"))
                if not isinstance(existing_logs, list):
                    existing_logs = []
            except json.JSONDecodeError:
                existing_logs = []
        else:
            existing_logs = []

        existing_logs.append(log_entry)
        DEBUG_LOG_PATH.write_text(json.dumps(existing_logs, indent=2), encoding="utf-8")

    def detect_with_hf(self, image, candidate_labels: list[str]):
        device = "cuda" if torch.cuda.is_available() else "cpu"
        model = self.hf_model.to(device)
        text_prompt = ". ".join(candidate_labels) + "."
        print("[ML] Running Grounding DINO inference")
        inputs = self.processor(images=image, text=text_prompt, return_tensors="pt")
        inputs = {
            key: value.to(device) if hasattr(value, "to") else value
            for key, value in inputs.items()
        }

        with torch.no_grad():
            outputs = model(**inputs)

        results = self.processor.post_process_grounded_object_detection(
            outputs,
            inputs["input_ids"],
            threshold=0.1,
            text_threshold=0.1,
            target_sizes=[image.size[::-1]],
        )

        detections: list[dict] = []

        if results:
            text_labels = results[0].get("text_labels", results[0]["labels"])

            for score, label, box in zip(
                results[0]["scores"],
                text_labels,
                results[0]["boxes"],
            ):
                label_text = self.normalize_label(str(label))
                if label_text is None:
                    continue
                if label_text not in candidate_labels:
                    continue
                confidence = float(score)
                if confidence < DINO_CONFIDENCE_FLOORS.get(label_text, 0.15):
                    continue
                bbox = [round(v, 2) for v in box.tolist()]
                print("[ML] Detected:", label_text)
                print(f"[ML] {label_text} detected with confidence {confidence:.2f} bbox={bbox}")
                detections.append(
                    {
                        "label": label_text,
                        "confidence": confidence,
                        "bbox": bbox,
                        "model": "grounding_dino",
                    }
                )

        return detections

    def detect_with_yolo(self, image_path: str) -> list[dict]:
        if self.yolo_model is None:
            return []

        print("[ML] Running YOLO inference")
        results = self.yolo_model.predict(
            source=image_path,
            conf=self.conf,
            imgsz=960,
            verbose=False,
        )

        detections: list[dict] = []
        for result in results:
            boxes = result.boxes
            if boxes is None:
                continue

            for index in range(len(boxes)):
                cls_id = int(boxes.cls[index].item())
                raw_label = str(self.yolo_model.names[cls_id])
                label = YOLO_LABEL_MAP.get(raw_label, raw_label.replace("_", " "))
                confidence = float(boxes.conf[index].item())
                xyxy = [round(float(v), 2) for v in boxes.xyxy[index].tolist()]
                print(f"[ML] YOLO {label} detected with confidence {confidence:.2f} bbox={xyxy}")
                detections.append(
                    {
                        "label": label,
                        "confidence": confidence,
                        "bbox": xyxy,
                        "model": "yolo",
                    }
                )

        return detections

    @staticmethod
    def normalize_label(raw_label: str) -> str | None:
        label = raw_label.lower().replace("##", "").strip()

        if "pothole" in label or "hole" in label:
            return "pothole"
        if "water logging" in label or "water" in label or "flood" in label:
            return "water logging on road"
        if "streetlight" in label or "street light" in label or "brokenlight" in label:
            return "broken streetlight"
        if "drainage" in label or "blockage" in label or "drain" in label:
            return "drainage blockage"
        if "road obstruction" in label or "obstruction" in label or "blocked road" in label:
            return "road obstruction"

        return None

    def merge_detections(self, yolo_detections: list[dict], dino_detections: list[dict], image_size: tuple[int, int]) -> list[dict]:
        merged: list[dict] = []
        best_by_label: dict[str, dict] = {}

        for detection in yolo_detections + dino_detections:
            enriched = dict(detection)
            label = str(enriched["label"])
            score = self.issue_priority_score(enriched, image_size)
            enriched["_priority_score"] = score
            severity = self.estimate_severity(label, enriched["bbox"], image_size)
            if severity is not None:
                enriched["severity"] = severity

            current = best_by_label.get(label)
            if current is None or enriched["_priority_score"] > current["_priority_score"]:
                best_by_label[label] = enriched

        merged = sorted(best_by_label.values(), key=lambda item: item["_priority_score"], reverse=True)
        for detection in merged:
            detection.pop("_priority_score", None)
        return merged

    def select_primary_issue(self, detections: list[dict], image_size: tuple[int, int]) -> str | None:
        if not detections:
            return None

        ranked = sorted(
            detections,
            key=lambda item: self.issue_priority_score(item, image_size),
            reverse=True,
        )
        return str(ranked[0]["label"])

    @staticmethod
    def issue_priority_score(detection: dict, image_size: tuple[int, int]) -> float:
        label = str(detection.get("label", ""))
        confidence = float(detection.get("confidence", 0.0))
        bbox = detection.get("bbox", [0, 0, 0, 0])
        model_name = str(detection.get("model", ""))
        image_width, image_height = image_size

        if len(bbox) != 4 or image_width <= 0 or image_height <= 0:
            return confidence

        x1, y1, x2, y2 = [float(value) for value in bbox]
        bbox_width = max(1.0, x2 - x1)
        bbox_height = max(1.0, y2 - y1)
        center_y_ratio = ((y1 + y2) / 2.0) / float(image_height)
        area_ratio = (bbox_width * bbox_height) / float(image_width * image_height)
        aspect_ratio = bbox_height / bbox_width

        score = confidence

        if label in {"pothole", "water logging on road", "drainage blockage", "road damage"}:
            score *= 1.0 + center_y_ratio
        elif label == "road obstruction":
            score *= 1.0 + (0.6 * center_y_ratio) + min(area_ratio * 2.0, 0.5)
        elif label == "broken streetlight":
            upper_half_bonus = max(0.0, 0.7 - center_y_ratio)
            score *= 1.0 + min(aspect_ratio * 0.2, 0.4) + upper_half_bonus

        if model_name == "yolo":
            score *= 1.25

        return score

    @staticmethod
    def estimate_severity(label: str, bbox: list[float], image_size: tuple[int, int]) -> str | None:
        if "pothole" not in label.lower():
            return None

        image_width, image_height = image_size
        if image_width <= 0 or image_height <= 0:
            return None

        x1, y1, x2, y2 = bbox
        bbox_width = max(0.0, x2 - x1)
        bbox_height = max(0.0, y2 - y1)
        area_ratio = (bbox_width * bbox_height) / float(image_width * image_height)

        if area_ratio < 0.02:
            return "low"
        if area_ratio < 0.08:
            return "medium"
        return "high"

def get_hybrid_detector(weights_path: str, conf: float = 0.15) -> HybridRoadDetector:
    cache_key = (str(Path(weights_path).resolve()), conf)

    if cache_key not in _DETECTORS:
        _DETECTORS[cache_key] = HybridRoadDetector(weights_path=weights_path, conf=conf)

    return _DETECTORS[cache_key]
