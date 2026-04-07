from __future__ import annotations

import json
import time
from datetime import datetime
from pathlib import Path

from PIL import Image
import torch
from transformers import AutoModelForZeroShotObjectDetection, AutoProcessor
from ultralytics import YOLO

MODEL_ID = "IDEA-Research/grounding-dino-base"
YOLO_CONF_THRESHOLD = 0.10
YOLO_IOU_THRESHOLD = 0.45
YOLO_IMAGE_SIZE = 1280
GROUNDING_DINO_BOX_THRESHOLD = 0.10
GROUNDING_DINO_TEXT_THRESHOLD = 0.10
DINO_PROMPT_LABELS = [
    "pothole",
    "water logging",
    "road damage",
    "road obstruction",
    "broken streetlight",
    "drainage blockage",
]
YOLO_CLASS_MAP = {
    0: "Pothole",
    1: "Road Surface Damage",
    2: "Water Logging",
}
MIN_CONFIDENCE_BY_ISSUE = {
    "Pothole": 0.18,
    "Road Surface Damage": 0.16,
    "Water Logging": 0.14,
    "Road Obstruction": 0.22,
    "Street Light Not Working": 0.24,
    "Drainage Blockage": 0.18,
}
_DETECTORS: dict[tuple[str, float], "HybridRoadDetector"] = {}
DEBUG_LOG_PATH = Path("runs") / "ml_debug_log.json"


def get_default_weights_path() -> Path:
    return Path(__file__).resolve().parent / "models" / "road_damage" / "weights" / "best.pt"


class HybridRoadDetector:
    def __init__(self, weights_path: str | None = None, conf: float = YOLO_CONF_THRESHOLD) -> None:
        self.weights_path = Path(weights_path) if weights_path is not None else get_default_weights_path()
        self.conf = conf
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        self.text_prompt = ". ".join(label.lower().strip(". ") for label in DINO_PROMPT_LABELS) + "."
        self.yolo_model: YOLO | None = None

        print(f"[ML] Running on device: {self.device}")
        self.processor = self._load_processor()
        self.hf_model = self._load_grounding_dino_model()
        self._load_yolo_model()

    def _load_processor(self):
        print("[ML] Loading Grounding DINO processor...")
        try:
            processor = AutoProcessor.from_pretrained(MODEL_ID, local_files_only=True)
            print("[ML] Grounding DINO processor loaded from local cache")
            return processor
        except Exception:
            processor = AutoProcessor.from_pretrained(MODEL_ID)
            print("[ML] Grounding DINO processor loaded successfully")
            return processor

    def _load_grounding_dino_model(self):
        print("[ML] Loading Grounding DINO model...")
        try:
            model = AutoModelForZeroShotObjectDetection.from_pretrained(
                MODEL_ID,
                local_files_only=True,
            )
            print("[ML] Grounding DINO model loaded from local cache")
        except Exception:
            model = AutoModelForZeroShotObjectDetection.from_pretrained(MODEL_ID)
            print("[ML] Grounding DINO model loaded successfully")

        model = model.to(self.device)
        model.eval()
        return model

    def _load_yolo_model(self) -> None:
        if not self.weights_path.exists():
            print(f"[ML WARNING] YOLO weights not found: {self.weights_path}")
            return

        print("[ML DEBUG] YOLO weights loaded from:", self.weights_path)
        print("[ML] Loading YOLO model...")
        self.yolo_model = YOLO(str(self.weights_path))
        print("[ML] YOLO loaded successfully")
        print("[ML DEBUG] YOLO class names:", self.yolo_model.names)

    def detect(self, image_path: str) -> dict:
        image_name = Path(image_path).name
        started_at = time.perf_counter()
        print(f"[ML] Running detection on image: {image_name}")
        image = self._load_image(image_path)

        yolo_detections = self._run_yolo(image_path)
        dino_detections = self._run_grounding_dino(image)
        detections = self._merge_detections(yolo_detections, dino_detections, image.size)
        issue = detections[0]["label"] if detections else "Unknown"
        severity = detections[0].get("severity", "low") if detections else "low"
        confidence = float(detections[0].get("confidence", 0.0)) if detections else 0.0

        if yolo_detections and dino_detections:
            source = "hybrid"
        elif yolo_detections:
            source = "yolo"
        elif dino_detections:
            source = "grounding_dino"
        else:
            source = "none"

        print(f"[ML] YOLO detections: {len(yolo_detections)}")
        print(f"[ML] Grounding DINO detections: {len(dino_detections)}")
        print(f"[ML] Final detections: {len(detections)}")

        result = {
            "source": source,
            "issue": issue,
            "severity": severity,
            "confidence": round(confidence, 4),
            "detections": detections,
        }
        self.append_debug_log(
            image_name=image_name,
            model_used=source,
            detections_count=len(detections),
            processing_time_ms=round((time.perf_counter() - started_at) * 1000),
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
        entry = {
            "image": image_name,
            "model_used": model_used,
            "detections": detections_count,
            "processing_time_ms": processing_time_ms,
            "timestamp": datetime.now().isoformat(timespec="seconds"),
        }

        if DEBUG_LOG_PATH.exists():
            try:
                existing = json.loads(DEBUG_LOG_PATH.read_text(encoding="utf-8"))
                if not isinstance(existing, list):
                    existing = []
            except json.JSONDecodeError:
                existing = []
        else:
            existing = []

        existing.append(entry)
        DEBUG_LOG_PATH.write_text(json.dumps(existing, indent=2), encoding="utf-8")

    @staticmethod
    def _load_image(image_path: str) -> Image.Image:
        try:
            image = Image.open(image_path).convert("RGB")
        except Exception as error:
            raise RuntimeError(f"Failed to read image: {error}") from error

        print("[ML] Image size:", image.size)
        return image

    def _run_yolo(self, image_path: str) -> list[dict]:
        if self.yolo_model is None:
            return []

        print("[ML] Running YOLO inference")
        results = self.yolo_model.predict(
            source=image_path,
            conf=self.conf,
            iou=YOLO_IOU_THRESHOLD,
            imgsz=YOLO_IMAGE_SIZE,
            verbose=True,
        )

        detections: list[dict] = []
        for result in results:
            boxes = result.boxes
            if boxes is None:
                continue

            for index in range(len(boxes)):
                cls_id = int(boxes.cls[index].item())
                confidence = float(boxes.conf[index].item())
                xyxy = [round(float(value), 2) for value in boxes.xyxy[index].tolist()]
                label = self._resolve_yolo_label(cls_id)
                print(f"[ML] Detected {label} with confidence {confidence:.2f}")
                detections.append(
                    {
                        "label": label,
                        "confidence": confidence,
                        "bbox": xyxy,
                        "model": "yolo",
                    }
                )

        return detections

    def _resolve_yolo_label(self, cls_id: int) -> str:
        if cls_id in YOLO_CLASS_MAP:
            return YOLO_CLASS_MAP[cls_id]

        if self.yolo_model is None:
            return str(cls_id)

        names = self.yolo_model.names
        if isinstance(names, dict):
            raw_name = names.get(cls_id, str(cls_id))
        elif isinstance(names, list) and 0 <= cls_id < len(names):
            raw_name = names[cls_id]
        else:
            raw_name = str(cls_id)

        return self._normalize_issue_label(raw_name) or str(raw_name).replace("_", " ").title()

    def _run_grounding_dino(self, image: Image.Image) -> list[dict]:
        print("[ML] Running Grounding DINO inference")
        inputs = self.processor(images=image, text=self.text_prompt, return_tensors="pt")
        inputs = {
            key: value.to(self.device) if hasattr(value, "to") else value
            for key, value in inputs.items()
        }

        with torch.no_grad():
            outputs = self.hf_model(**inputs)

        results = self.processor.post_process_grounded_object_detection(
            outputs,
            inputs["input_ids"],
            threshold=GROUNDING_DINO_BOX_THRESHOLD,
            text_threshold=GROUNDING_DINO_TEXT_THRESHOLD,
            target_sizes=[image.size[::-1]],
        )

        detections: list[dict] = []
        if not results:
            return detections

        raw_result = results[0]
        text_labels = raw_result.get("text_labels")
        if text_labels is None:
            text_labels = [self._decode_grounding_label(label) for label in raw_result["labels"]]

        for score, raw_label, box in zip(
            raw_result["scores"],
            text_labels,
            raw_result["boxes"],
        ):
            label = self._normalize_issue_label(raw_label)
            if label is None:
                continue
            confidence = float(score)
            bbox = [round(float(value), 2) for value in box.tolist()]
            if confidence < MIN_CONFIDENCE_BY_ISSUE.get(label, GROUNDING_DINO_BOX_THRESHOLD):
                continue
            if not self._passes_geometry_filter(label, bbox, image.size):
                continue
            print(f"[ML] Detected {label} with confidence {confidence:.2f}")
            detections.append(
                {
                    "label": label,
                    "confidence": confidence,
                    "bbox": bbox,
                    "model": "grounding_dino",
                }
            )

        return detections

    def _decode_grounding_label(self, label: object) -> str:
        if isinstance(label, str):
            return label

        try:
            raw_value = int(label.item()) if hasattr(label, "item") else int(label)
        except Exception:
            return str(label)

        try:
            if hasattr(self.processor, "decode"):
                decoded = self.processor.decode([raw_value], skip_special_tokens=True).strip()
            else:
                decoded = self.processor.tokenizer.decode([raw_value], skip_special_tokens=True).strip()
            return decoded or str(raw_value)
        except Exception:
            return str(raw_value)

    @staticmethod
    def _normalize_issue_label(raw_label: object) -> str | None:
        label = str(raw_label).lower().replace("_", " ").replace("-", " ").strip()
        label = " ".join(label.split())

        if not label:
            return None
        if "pothole" in label or "hole in road" in label:
            return "Pothole"
        if (
            "water logging" in label
            or "waterlogged" in label
            or "flooded road" in label
            or "standing water" in label
            or "flood" in label
        ):
            return "Water Logging"
        if (
            "road damage" in label
            or "road surface damage" in label
            or "damaged road" in label
            or "broken road surface" in label
            or "cracked asphalt" in label
            or "damaged asphalt" in label
        ):
            return "Road Surface Damage"
        if (
            "road obstruction" in label
            or "obstruction" in label
            or "blocked road" in label
            or "barrier" in label
            or "debris" in label
            or "fallen tree" in label
        ):
            return "Road Obstruction"
        if (
            "broken streetlight" in label
            or "broken street light" in label
            or "streetlight" in label
            or "street light" in label
            or "electric pole" in label
            or "light pole" in label
        ):
            return "Street Light Not Working"
        if (
            "drainage blockage" in label
            or "blocked drain" in label
            or "drain blockage" in label
            or "drainage" in label
            or "manhole overflow" in label
        ):
            return "Drainage Blockage"

        return None

    def _merge_detections(
        self,
        yolo_detections: list[dict],
        dino_detections: list[dict],
        image_size: tuple[int, int],
    ) -> list[dict]:
        best_by_label: dict[str, dict] = {}

        for detection in yolo_detections + dino_detections:
            label = str(detection.get("label", "")).strip()
            if not label:
                continue

            enriched = {
                "label": label,
                "confidence": round(float(detection.get("confidence", 0.0)), 4),
                "bbox": [round(float(value), 2) for value in detection.get("bbox", [])[:4]],
                "model": detection.get("model", "unknown"),
            }
            enriched["severity"] = self._estimate_severity(enriched["bbox"], image_size)

            current = best_by_label.get(label)
            if current is None or self._ranking_score(enriched) > self._ranking_score(current):
                best_by_label[label] = enriched

        return sorted(best_by_label.values(), key=self._ranking_score, reverse=True)

    def _ranking_score(self, detection: dict) -> float:
        confidence = float(detection.get("confidence", 0.0))
        label = str(detection.get("label", ""))
        model_name = str(detection.get("model", ""))
        return (
            confidence
            + self._issue_priority_bonus(label)
            + (0.05 if model_name == "yolo" else 0.0)
        )

    @staticmethod
    def _issue_priority_bonus(label: str) -> float:
        return {
            "Pothole": 0.18,
            "Water Logging": 0.16,
            "Road Surface Damage": 0.12,
            "Road Obstruction": 0.06,
            "Drainage Blockage": 0.04,
            "Street Light Not Working": 0.02,
        }.get(label, 0.0)

    @staticmethod
    def _passes_geometry_filter(
        label: str,
        bbox: list[float],
        image_size: tuple[int, int],
    ) -> bool:
        if len(bbox) != 4:
            return False

        image_width, image_height = image_size
        if image_width <= 0 or image_height <= 0:
            return False

        x1, y1, x2, y2 = [float(value) for value in bbox]
        width = max(1.0, x2 - x1)
        height = max(1.0, y2 - y1)
        area_ratio = (width * height) / float(image_width * image_height)
        aspect_ratio = height / width
        center_y_ratio = ((y1 + y2) / 2.0) / float(image_height)

        if label == "Pothole":
            return center_y_ratio >= 0.45 and 0.0005 <= area_ratio <= 0.20
        if label == "Road Surface Damage":
            return center_y_ratio >= 0.35 and 0.005 <= area_ratio <= 0.45
        if label == "Water Logging":
            return center_y_ratio >= 0.45 and area_ratio >= 0.01
        if label == "Road Obstruction":
            return center_y_ratio >= 0.35 and aspect_ratio <= 1.80 and area_ratio >= 0.003
        if label == "Street Light Not Working":
            return center_y_ratio <= 0.70 and aspect_ratio >= 1.40 and area_ratio <= 0.15
        if label == "Drainage Blockage":
            return center_y_ratio >= 0.45 and area_ratio <= 0.08
        return True

    @staticmethod
    def _estimate_severity(bbox: list[float], image_size: tuple[int, int]) -> str:
        if len(bbox) != 4:
            return "low"

        image_width, image_height = image_size
        if image_width <= 0 or image_height <= 0:
            return "low"

        x1, y1, x2, y2 = [float(value) for value in bbox]
        width = max(0.0, x2 - x1)
        height = max(0.0, y2 - y1)
        area_ratio = (width * height) / float(image_width * image_height)

        if area_ratio >= 0.10:
            return "high"
        if area_ratio >= 0.03:
            return "medium"
        return "low"


def format_for_flutter(result: dict) -> dict:
    detections = result.get("detections", [])
    top_detection = detections[0] if detections else {}
    boxes: list[dict] = []

    for detection in detections:
        bbox = detection.get("bbox", [])
        if len(bbox) != 4:
            continue

        x1, y1, x2, y2 = [float(value) for value in bbox]
        boxes.append(
            {
                "x": round(x1, 2),
                "y": round(y1, 2),
                "width": round(max(0.0, x2 - x1), 2),
                "height": round(max(0.0, y2 - y1), 2),
            }
        )

    return {
        "issue": str(result.get("issue") or top_detection.get("label") or "Unknown"),
        "severity": str(result.get("severity") or top_detection.get("severity") or "low").lower(),
        "confidence": round(float(result.get("confidence") or top_detection.get("confidence") or 0.0), 4),
        "boxes": boxes,
    }


def get_hybrid_detector(weights_path: str, conf: float = YOLO_CONF_THRESHOLD) -> HybridRoadDetector:
    cache_key = (str(Path(weights_path).resolve()), conf)
    if cache_key not in _DETECTORS:
        _DETECTORS[cache_key] = HybridRoadDetector(weights_path=weights_path, conf=conf)
    return _DETECTORS[cache_key]
