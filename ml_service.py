from __future__ import annotations

import json
import time
from datetime import datetime
from pathlib import Path

from PIL import Image
import torch
from transformers import AutoModelForZeroShotObjectDetection, AutoProcessor
from ultralytics import YOLO

BASE_DIR = Path(__file__).resolve().parent
MODEL_ID = "IDEA-Research/grounding-dino-base"
POTHOLE_MODEL_PATH = BASE_DIR / "models" / "pretrained" / "pothole_yolo.pt"
POTHOLE_CONF_THRESHOLD = 0.40
YOLO_CONF_THRESHOLD = 0.10
YOLO_IOU_THRESHOLD = 0.45
YOLO_IMAGE_SIZE = 1280
GROUNDING_DINO_BOX_THRESHOLD = 0.30
GROUNDING_DINO_TEXT_THRESHOLD = 0.25
DINO_TEXT_PROMPT = """
large pothole in asphalt road.
pothole filled with water.
flooded road with standing water.
broken electric street light pole.
damaged street light pole on roadside.
fallen tree blocking road.
vehicle blocking road.
object obstructing road.
""".strip()
_DETECTORS: dict[tuple[str, float], "HybridRoadDetector"] = {}
DEBUG_LOG_PATH = Path("runs") / "ml_debug_log.json"


def get_default_weights_path() -> Path:
    return BASE_DIR / "models" / "road_damage" / "weights" / "best.pt"


class HybridRoadDetector:
    def __init__(self, weights_path: str | None = None, conf: float = YOLO_CONF_THRESHOLD) -> None:
        self.weights_path = Path(weights_path) if weights_path is not None else get_default_weights_path()
        self.pothole_model_path = POTHOLE_MODEL_PATH
        self.conf = conf
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        self.text_prompt = DINO_TEXT_PROMPT
        self.using_dedicated_pothole_model = False
        self.pothole_model: YOLO | None = None
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
        candidate_paths = [
            ("pretrained pothole", self.pothole_model_path),
            ("fallback road-damage", self.weights_path),
        ]

        for source_name, candidate_path in candidate_paths:
            if not candidate_path.exists():
                continue

            print(f"[ML] Loading YOLO model from {candidate_path} ({source_name})")
            try:
                model = YOLO(str(candidate_path))
            except Exception as error:
                print(f"[ML WARNING] Failed to load {source_name} model: {error}")
                continue

            self.pothole_model = model
            self.using_dedicated_pothole_model = candidate_path.resolve() == self.pothole_model_path.resolve()
            self.yolo_model = model
            print("[ML] YOLO loaded successfully")
            print("[ML DEBUG] YOLO class names:", model.names)
            return

        print(
            "[ML WARNING] No YOLO pothole model available. "
            f"Checked {self.pothole_model_path} and {self.weights_path}."
        )

    def detect(self, image_path: str) -> dict:
        image_name = Path(image_path).name
        started_at = time.perf_counter()
        print(f"[ML] Running detection on image: {image_name}")
        image = self._load_image(image_path)
        pothole_result = self.detect_pothole(image_path)
        pothole_detected = False
        pothole_detections: list[dict] = []
        pothole_confidence = 0.0
        pothole_boxes: list[dict] = []

        if pothole_result:
            pothole_detected = True
            pothole_detections = list(pothole_result.get("detections", []))
            pothole_confidence = float(pothole_result.get("confidence", 0.0))
            pothole_boxes = list(pothole_result.get("boxes", []))

        dino_result = self._run_grounding_dino(image)
        dino_detections = list(dino_result.get("detections", []))
        dino_labels = [str(label).lower().strip() for label in dino_result.get("detected_labels", [])]
        dino_confidence = float(dino_result.get("confidence", 0.0))
        dino_boxes = list(dino_result.get("boxes", []))

        detected_labels: list[str] = []
        if pothole_detected:
            detected_labels.append("pothole")
        detected_labels.extend(label for label in dino_labels if label)

        detections = self._merge_detections(pothole_detections, dino_detections, image.size)
        issue = self._classify_issue(detected_labels)
        selected_detection = self._select_detection_for_issue(detections, issue)

        confidence = max(pothole_confidence, dino_confidence)

        severity = selected_detection.get("severity", "low") if selected_detection is not None else "low"
        boxes = self._serialize_detection_boxes(detections)
        if not boxes:
            boxes = pothole_boxes + dino_boxes

        if pothole_detected and dino_detections:
            source = "hybrid"
        elif pothole_detected:
            source = "pothole_yolo"
        elif dino_detections:
            source = "grounding_dino"
        else:
            source = "none"

        result = {
            "source": source,
            "issue": issue,
            "severity": severity,
            "confidence": round(confidence, 4),
            "detections": detections,
            "boxes": boxes,
        }

        print(f"[ML] Pothole detections: {len(pothole_detections)}")
        print(f"[ML] Grounding DINO detections: {len(dino_detections)}")
        print(f"[ML] Final detections: {len(detections)}")
        print(f"[ML] Final issue: {result.get('issue')}")

        self.append_debug_log(
            image_name=image_name,
            model_used=str(result.get("source", "none")),
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

    def detect_pothole(self, image_path: str) -> dict | None:
        if self.pothole_model is None:
            return None

        print("[ML] Running pothole YOLO inference")
        results = self.pothole_model.predict(
            source=image_path,
            conf=POTHOLE_CONF_THRESHOLD,
            iou=YOLO_IOU_THRESHOLD,
            imgsz=YOLO_IMAGE_SIZE,
            verbose=False,
        )

        detections: list[dict] = []
        image_size: tuple[int, int] | None = None

        for result in results:
            boxes = result.boxes
            if image_size is None and getattr(result, "orig_shape", None):
                image_size = (int(result.orig_shape[1]), int(result.orig_shape[0]))
            if boxes is None:
                continue

            for index in range(len(boxes)):
                cls_id = int(boxes.cls[index].item())
                raw_name = self._resolve_model_label(self.pothole_model, cls_id)
                if not self.using_dedicated_pothole_model and not self._is_pothole_label(raw_name):
                    continue

                confidence = float(boxes.conf[index].item())
                bbox = [round(float(value), 2) for value in boxes.xyxy[index].tolist()]
                print(f"[ML] Detected Pothole with confidence {confidence:.2f}")
                detections.append(
                    {
                        "label": "Pothole",
                        "confidence": confidence,
                        "bbox": bbox,
                        "model": "pothole_yolo",
                    }
                )

        if not detections:
            return None

        if image_size is None:
            image = self._load_image(image_path)
            image_size = image.size

        detections = sorted(detections, key=lambda item: float(item.get("confidence", 0.0)), reverse=True)
        top_detection = detections[0]
        severity = self._estimate_severity(top_detection["bbox"], image_size)
        return {
            "source": "pothole_yolo",
            "issue": "Pothole",
            "severity": severity,
            "confidence": round(float(top_detection.get("confidence", 0.0)), 4),
            "detections": detections,
            "boxes": self._serialize_detection_boxes(detections),
        }

    @staticmethod
    def _resolve_model_label(model: YOLO | None, cls_id: int) -> str:
        if model is None:
            return str(cls_id)

        names = model.names
        if isinstance(names, dict):
            raw_name = names.get(cls_id, str(cls_id))
        elif isinstance(names, list) and 0 <= cls_id < len(names):
            raw_name = names[cls_id]
        else:
            raw_name = str(cls_id)

        return str(raw_name).replace("_", " ").strip()

    @staticmethod
    def _is_pothole_label(raw_label: str) -> bool:
        label = str(raw_label).lower()
        return any(token in label for token in ["pothole", "hole"])

    def _run_grounding_dino(self, image: Image.Image) -> dict[str, object]:
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
            # The installed Transformers version uses threshold= for the box score cutoff.
            threshold=GROUNDING_DINO_BOX_THRESHOLD,
            text_threshold=GROUNDING_DINO_TEXT_THRESHOLD,
            target_sizes=[image.size[::-1]],
        )

        detections: list[dict] = []
        detected_labels: list[str] = []
        boxes: list[dict] = []
        max_confidence = 0.0
        if not results:
            return {
                "detections": detections,
                "detected_labels": detected_labels,
                "issue": "Road OK",
                "confidence": 0.0,
                "boxes": boxes,
            }

        raw_result = results[0]
        text_labels = raw_result.get("text_labels")
        if text_labels is None:
            text_labels = [self._decode_grounding_label(label) for label in raw_result["labels"]]

        for score, raw_label, box in zip(
            raw_result["scores"],
            text_labels,
            raw_result["boxes"],
        ):
            confidence = float(score)
            if confidence < 0.30:
                continue

            x1, y1, x2, y2 = box.tolist()
            width = x2 - x1
            height = y2 - y1
            img_w, img_h = image.size
            if width > img_w * 0.8 or height > img_h * 0.8:
                continue

            label_text = str(raw_label).lower()
            detected_labels.append(label_text)
            max_confidence = max(max_confidence, confidence)
            boxes.append(self._serialize_box([x1, y1, x2, y2]))

            label = self._normalize_issue_label(raw_label)
            if label is None:
                continue
            bbox = [round(float(value), 2) for value in box.tolist()]
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

        issue = self._classify_issue(
            detected_labels,
            has_boxes=bool(boxes),
            fallback_issue=str(detections[0].get("label", "")) if detections else "Road OK",
        )
        return {
            "detections": detections,
            "detected_labels": detected_labels,
            "issue": issue,
            "confidence": max_confidence,
            "boxes": boxes,
        }

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
        if "pothole" in label:
            return "Pothole"
        if (
            "water" in label
            or "water logging" in label
            or "flooded road" in label
            or "standing water" in label
            or "flood" in label
        ):
            return "Water Logging"
        if (
            "pole" in label
            or "light" in label
            or "streetlight" in label
            or "street light" in label
        ):
            return "Broken Streetlight"
        if (
            "tree" in label
            or "vehicle" in label
            or "road obstruction" in label
            or "obstructing" in label
            or "obstruction" in label
            or "blocked road" in label
            or "barrier" in label
            or "debris" in label
            or "fallen tree" in label
            or "block" in label
        ):
            return "Road Obstruction"

        return None

    @staticmethod
    def _classify_issue(
        detected_labels: list[str],
        has_boxes: bool = False,
        fallback_issue: str = "Road OK",
    ) -> str:
        normalized_labels = [str(label).lower().strip() for label in detected_labels if str(label).strip()]
        issue = "Road OK"

        if any("pothole" in label for label in normalized_labels):
            issue = "Pothole"
        elif any(keyword in label for label in normalized_labels for keyword in ["water", "flood"]):
            issue = "Water Logging"
        elif any(keyword in label for label in normalized_labels for keyword in ["pole", "light"]):
            issue = "Broken Streetlight"
        elif any(
            keyword in label
            for label in normalized_labels
            for keyword in ["tree", "vehicle", "obstruction"]
        ):
            issue = "Road Obstruction"
        elif normalized_labels:
            issue = fallback_issue or "Road OK"
        elif has_boxes:
            issue = fallback_issue or "Road OK"

        return issue

    @staticmethod
    def _serialize_box(bbox: list[float]) -> dict:
        if len(bbox) != 4:
            return {"x": 0.0, "y": 0.0, "width": 0.0, "height": 0.0}

        x1, y1, x2, y2 = [float(value) for value in bbox]
        return {
            "x": round(x1, 2),
            "y": round(y1, 2),
            "width": round(max(0.0, x2 - x1), 2),
            "height": round(max(0.0, y2 - y1), 2),
        }

    def _serialize_detection_boxes(self, detections: list[dict]) -> list[dict]:
        boxes: list[dict] = []
        for detection in detections:
            bbox = detection.get("bbox", [])
            if len(bbox) != 4:
                continue
            boxes.append(self._serialize_box([float(value) for value in bbox]))
        return boxes

    @staticmethod
    def _select_detection_for_issue(detections: list[dict], issue: str) -> dict | None:
        issue_tokens = {
            "Pothole": ["pothole", "hole", "crack"],
            "Water Logging": ["water", "flood"],
            "Broken Streetlight": ["pole", "light", "streetlight"],
            "Road Obstruction": ["tree", "vehicle", "obstruction", "block"],
        }.get(issue, [issue.lower()])

        for detection in detections:
            label = str(detection.get("label", "")).lower()
            if any(token in label for token in issue_tokens):
                return detection

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
            "Road Obstruction": 0.06,
            "Broken Streetlight": 0.02,
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
    boxes = list(result.get("boxes", []))

    if not boxes:
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
        "issue": str(result.get("issue") or top_detection.get("label") or "Road OK"),
        "severity": str(result.get("severity") or top_detection.get("severity") or "low").lower(),
        "confidence": round(float(result.get("confidence") or top_detection.get("confidence") or 0.0), 4),
        "boxes": boxes,
    }


def get_hybrid_detector(weights_path: str, conf: float = YOLO_CONF_THRESHOLD) -> HybridRoadDetector:
    cache_key = (str(Path(weights_path).resolve()), conf)
    if cache_key not in _DETECTORS:
        _DETECTORS[cache_key] = HybridRoadDetector(weights_path=weights_path, conf=conf)
    return _DETECTORS[cache_key]
