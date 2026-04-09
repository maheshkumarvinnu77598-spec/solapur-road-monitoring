from __future__ import annotations

import concurrent.futures
import json
import os
import time
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any

from PIL import Image
import torch
from transformers import AutoModelForZeroShotObjectDetection, AutoProcessor
from ultralytics import YOLO

try:
    from inference_sdk import InferenceHTTPClient
except ImportError:
    InferenceHTTPClient = None  # type: ignore[assignment]


BASE_DIR = Path(__file__).resolve().parent
MODEL_ID = "IDEA-Research/grounding-dino-base"
POTHOLE_MODEL_PATH = BASE_DIR / "models" / "pretrained" / "pothole_yolo.pt"
YOLO_FALLBACK_WEIGHTS_PATH = BASE_DIR / "models" / "road_damage" / "weights" / "best.pt"

ROBOFLOW_API_URL = os.getenv("ROBOFLOW_API_URL", "https://serverless.roboflow.com")
ROBOFLOW_API_KEY = os.getenv("ROBOFLOW_API_KEY", "").strip()
ROBOFLOW_WORKSPACE_NAME = os.getenv("ROBOFLOW_WORKSPACE_NAME", "").strip()
ROBOFLOW_IMAGE_INPUT_NAME = os.getenv("ROBOFLOW_IMAGE_INPUT_NAME", "image").strip() or "image"
ROBOFLOW_REQUEST_TIMEOUT_SECONDS = float(
    os.getenv("ROBOFLOW_REQUEST_TIMEOUT_SECONDS", "1.5")
)

YOLO_CONF_THRESHOLD = 0.50
YOLO_IOU_THRESHOLD = 0.45
YOLO_IMAGE_SIZE = 1280
GROUNDING_DINO_BOX_THRESHOLD = 0.30
GROUNDING_DINO_TEXT_THRESHOLD = 0.25
MIN_DETECTION_CONFIDENCE = 0.50
LOCAL_YOLO_CONF_THRESHOLD = 0.10
LOCAL_GROUNDING_DINO_CONF_THRESHOLD = 0.30
ROBOFLOW_CONF_THRESHOLD = 0.50
GROUNDING_DINO_CLASS_CONF_THRESHOLDS = {
    "pothole": 0.30,
    "water_logging": 0.38,
    "road_obstruction": 0.35,
    "broken_streetlight": 0.35,
}

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

ROAD_ISSUE_CLASSES = (
    "pothole",
    "water_logging",
    "road_obstruction",
    "broken_streetlight",
)
DEBUG_LOG_PATH = Path("runs") / "ml_debug_log.json"
_DETECTORS: dict[tuple[str, float], "HybridRoadDetector"] = {}


@dataclass(frozen=True)
class DetectionModelConfig:
    name: str
    workflow_env: str
    default_workflow_id: str
    model_source: str
    local_backend: str


ROAD_ISSUE_MODELS = (
    DetectionModelConfig(
        name="pothole",
        workflow_env="ROBOFLOW_POTHOLE_WORKFLOW_ID",
        default_workflow_id="",
        model_source="pothole_model",
        local_backend="pothole_yolo",
    ),
    DetectionModelConfig(
        name="water_logging",
        workflow_env="ROBOFLOW_WATER_LOGGING_WORKFLOW_ID",
        default_workflow_id="",
        model_source="water_logging_model",
        local_backend="grounding_dino",
    ),
    DetectionModelConfig(
        name="road_obstruction",
        workflow_env="ROBOFLOW_ROAD_OBSTRUCTION_WORKFLOW_ID",
        default_workflow_id="",
        model_source="road_obstruction_model",
        local_backend="grounding_dino",
    ),
    DetectionModelConfig(
        name="broken_streetlight",
        workflow_env="ROBOFLOW_BROKEN_STREETLIGHT_WORKFLOW_ID",
        default_workflow_id="",
        model_source="broken_streetlight_model",
        local_backend="grounding_dino",
    ),
)

MODEL_CONFIG_BY_CLASS = {config.name: config for config in ROAD_ISSUE_MODELS}
MODEL_SOURCE_BY_CLASS = {
    config.name: config.model_source for config in ROAD_ISSUE_MODELS
}
DISPLAY_LABELS = {
    "pothole": "Pothole",
    "water_logging": "Water Logging",
    "road_obstruction": "Road Obstruction",
    "broken_streetlight": "Street Light Not Working",
}
RECOMMENDED_ACTIONS = {
    "HIGH": "Immediate repair required",
    "MEDIUM": "Schedule field inspection and clear the obstruction",
    "LOW": "Plan maintenance visit",
}


def get_default_weights_path() -> Path:
    return YOLO_FALLBACK_WEIGHTS_PATH


class HybridRoadDetector:
    def __init__(
        self,
        weights_path: str | None = None,
        conf: float = YOLO_CONF_THRESHOLD,
    ) -> None:
        self.weights_path = (
            Path(weights_path) if weights_path is not None else get_default_weights_path()
        )
        self.conf = max(conf, LOCAL_YOLO_CONF_THRESHOLD)
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        self.text_prompt = DINO_TEXT_PROMPT
        self.processor = self._load_processor()
        self.hf_model = self._load_grounding_dino_model()
        self.roboflow_client = self._load_roboflow_client()
        self.pothole_model = self._load_pothole_model()
        self.yolo_model = self.pothole_model

        print(f"[ML] Running on device: {self.device}")

    def _load_roboflow_client(self):
        if InferenceHTTPClient is None:
            print("[ML WARNING] inference_sdk is not installed. Roboflow disabled.")
            return None
        if not ROBOFLOW_API_KEY:
            print("[ML WARNING] ROBOFLOW_API_KEY not set. Roboflow disabled.")
            return None
        if not ROBOFLOW_WORKSPACE_NAME:
            print("[ML WARNING] ROBOFLOW_WORKSPACE_NAME not set. Roboflow disabled.")
            return None

        try:
            print("[ML] Roboflow client configured")
            return InferenceHTTPClient(
                api_url=ROBOFLOW_API_URL,
                api_key=ROBOFLOW_API_KEY,
            )
        except Exception as error:
            print(f"[ML WARNING] Failed to initialize Roboflow client: {error}")
            return None

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

    def _load_pothole_model(self) -> YOLO | None:
        for candidate_path in (POTHOLE_MODEL_PATH, self.weights_path):
            if not candidate_path.exists():
                continue

            print(f"[ML] Loading local YOLO model from {candidate_path}")
            try:
                model = YOLO(str(candidate_path))
            except Exception as error:
                print(f"[ML WARNING] Failed to load YOLO model {candidate_path}: {error}")
                continue

            print("[ML] YOLO loaded successfully")
            print("[ML DEBUG] YOLO class names:", model.names)
            return model

        print("[ML WARNING] No local YOLO model available for pothole fallback.")
        return None

    def detect(self, image_path: str) -> dict:
        return self.detect_road_issues(image_path)

    def detect_road_issues(self, image_path: str) -> dict:
        image_name = Path(image_path).name
        started_at = time.perf_counter()
        print(f"[ML] Running unified detection on image: {image_name}")
        image = self._load_image(image_path)

        roboflow_detections = self._run_roboflow_models(image_path)
        local_detections = self._run_local_models(image_path, image)
        detections = self._deduplicate_detections(roboflow_detections + local_detections)

        summary = self._build_summary(detections)
        priority = self._determine_priority(summary)
        recommended_action = self._determine_recommended_action(priority, summary)

        result = {
            "summary": summary,
            "detections": detections,
            "priority": priority,
            "recommended_action": recommended_action,
        }

        print(f"[ML] Roboflow detections: {len(roboflow_detections)}")
        print(f"[ML] Local detections: {len(local_detections)}")
        print(f"[ML] Final detections: {len(detections)}")
        print(f"[ML] Priority: {priority}")

        self.append_debug_log(
            image_name=image_name,
            model_used=self._model_usage_label(roboflow_detections, local_detections),
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

    def _run_roboflow_models(self, image_path: str) -> list[dict]:
        if self.roboflow_client is None:
            return []

        active_configs = [
            config for config in ROAD_ISSUE_MODELS if self._resolve_workflow_id(config)
        ]
        if not active_configs:
            return []

        detections: list[dict] = []
        with concurrent.futures.ThreadPoolExecutor(
            max_workers=min(len(active_configs), 4)
        ) as executor:
            future_map = {
                executor.submit(self._run_single_roboflow_model, config, image_path): config
                for config in active_configs
            }
            for future, config in [(future, future_map[future]) for future in future_map]:
                try:
                    detections.extend(
                        future.result(timeout=ROBOFLOW_REQUEST_TIMEOUT_SECONDS)
                    )
                except concurrent.futures.TimeoutError:
                    print(f"[ML WARNING] Roboflow timeout for {config.name}")
                except Exception as error:
                    print(f"[ML WARNING] Roboflow model {config.name} failed: {error}")

        return detections

    def _run_single_roboflow_model(
        self,
        config: DetectionModelConfig,
        image_path: str,
    ) -> list[dict]:
        workflow_id = self._resolve_workflow_id(config)
        if not workflow_id or self.roboflow_client is None:
            return []

        print(f"[ML] Running Roboflow workflow for {config.name}")
        workflow_output = self.roboflow_client.run_workflow(
            workspace_name=ROBOFLOW_WORKSPACE_NAME,
            workflow_id=workflow_id,
            images={ROBOFLOW_IMAGE_INPUT_NAME: image_path},
            use_cache=True,
        )
        return self._extract_workflow_detections(workflow_output, config)

    @staticmethod
    def _resolve_workflow_id(config: DetectionModelConfig) -> str:
        return os.getenv(config.workflow_env, config.default_workflow_id).strip()

    def _extract_workflow_detections(
        self,
        workflow_output: Any,
        config: DetectionModelConfig,
    ) -> list[dict]:
        detections: list[dict] = []

        def visit(node: Any) -> None:
            if isinstance(node, dict):
                bbox = self._extract_bbox(node)
                confidence = self._safe_float(
                    node.get("confidence", node.get("score", node.get("confidence_score", 0.0)))
                )
                raw_label = self._extract_raw_label(node) or config.name
                normalized_label = self._normalize_class_name(raw_label) or config.name

                if normalized_label == config.name and confidence >= ROBOFLOW_CONF_THRESHOLD:
                    detections.append(
                        self._make_detection(
                            class_name=config.name,
                            confidence=confidence,
                            bbox=bbox,
                            model_source=config.model_source,
                            backend="roboflow",
                        )
                    )

                for value in node.values():
                    visit(value)
                return

            if isinstance(node, list):
                for item in node:
                    visit(item)

        visit(workflow_output)
        return detections

    def _run_local_models(self, image_path: str, image: Image.Image) -> list[dict]:
        detections: list[dict] = []
        detections.extend(self._run_local_pothole_model(image_path))
        detections.extend(self._run_grounding_dino(image))
        return detections

    def _run_local_pothole_model(self, image_path: str) -> list[dict]:
        if self.pothole_model is None:
            return []

        print("[ML] Running local YOLO pothole inference")
        results = self.pothole_model.predict(
            source=image_path,
            conf=self.conf,
            iou=YOLO_IOU_THRESHOLD,
            imgsz=YOLO_IMAGE_SIZE,
            verbose=False,
        )

        detections: list[dict] = []
        for result in results:
            boxes = result.boxes
            if boxes is None:
                continue

            for index in range(len(boxes)):
                cls_id = int(boxes.cls[index].item())
                confidence = float(boxes.conf[index].item())
                raw_label = self._resolve_model_label(self.pothole_model, cls_id)
                normalized_label = self._normalize_class_name(raw_label)
                if normalized_label not in {"pothole", "water_logging"}:
                    continue
                if confidence < LOCAL_YOLO_CONF_THRESHOLD:
                    continue

                bbox = [float(value) for value in boxes.xyxy[index].tolist()]
                detections.append(
                    self._make_detection(
                        class_name=normalized_label,
                        confidence=confidence,
                        bbox=bbox,
                        model_source=MODEL_SOURCE_BY_CLASS[normalized_label],
                        backend="local_yolo",
                    )
                )
        return detections

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
            text_labels = [
                self._decode_grounding_label(label) for label in raw_result["labels"]
            ]

        for score, raw_label, box in zip(
            raw_result["scores"],
            text_labels,
            raw_result["boxes"],
        ):
            confidence = float(score)
            normalized_label = self._normalize_class_name(raw_label)
            if normalized_label not in ROAD_ISSUE_CLASSES:
                continue
            minimum_confidence = GROUNDING_DINO_CLASS_CONF_THRESHOLDS.get(
                normalized_label,
                LOCAL_GROUNDING_DINO_CONF_THRESHOLD,
            )
            if confidence < minimum_confidence:
                continue

            bbox = [float(value) for value in box.tolist()]
            if not self._passes_geometry_filter(normalized_label, bbox, image.size):
                continue

            detections.append(
                self._make_detection(
                    class_name=normalized_label,
                    confidence=confidence,
                    bbox=bbox,
                    model_source=MODEL_SOURCE_BY_CLASS[normalized_label],
                    backend="grounding_dino",
                )
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
                decoded = self.processor.tokenizer.decode(
                    [raw_value],
                    skip_special_tokens=True,
                ).strip()
            return decoded or str(raw_value)
        except Exception:
            return str(raw_value)

    @staticmethod
    def _extract_raw_label(node: dict[str, Any]) -> str:
        for key in (
            "class",
            "class_name",
            "label",
            "predicted_class",
            "prediction",
            "name",
            "issue",
        ):
            value = node.get(key)
            if isinstance(value, str) and value.strip():
                return value.strip()
        return ""

    @staticmethod
    def _extract_bbox(node: dict[str, Any]) -> list[float] | None:
        if {"x", "y", "width", "height"}.issubset(node):
            x = float(node["x"])
            y = float(node["y"])
            width = float(node["width"])
            height = float(node["height"])
            return [
                x - (width / 2.0),
                y - (height / 2.0),
                x + (width / 2.0),
                y + (height / 2.0),
            ]
        if {"x1", "y1", "x2", "y2"}.issubset(node):
            return [
                float(node["x1"]),
                float(node["y1"]),
                float(node["x2"]),
                float(node["y2"]),
            ]
        if {"left", "top", "right", "bottom"}.issubset(node):
            return [
                float(node["left"]),
                float(node["top"]),
                float(node["right"]),
                float(node["bottom"]),
            ]
        return None

    @staticmethod
    def _make_detection(
        class_name: str,
        confidence: float,
        bbox: list[float] | None,
        model_source: str,
        backend: str,
    ) -> dict:
        bbox_payload = HybridRoadDetector._serialize_box(
            bbox or [0.0, 0.0, 0.0, 0.0]
        )
        return {
            "class": class_name,
            "confidence": round(float(confidence), 4),
            "bbox": bbox_payload,
            "model_source": model_source,
            "backend": backend,
        }

    @staticmethod
    def _normalize_class_name(raw_label: object) -> str | None:
        label = str(raw_label).lower().replace("_", " ").replace("-", " ").strip()
        label = " ".join(label.split())

        if not label:
            return None
        if (
            "road damage" in label
            or "pothole" in label
            or "hole" in label
            or "crack" in label
        ):
            return "pothole"
        if (
            "water logging" in label
            or "waterlogged" in label
            or "standing water" in label
            or "flooded road" in label
            or "flood" in label
            or "water" in label
        ):
            return "water_logging"
        if (
            "street light" in label
            or "streetlight" in label
            or "light pole" in label
            or "electric pole" in label
            or "pole" in label
            or "light" in label
        ):
            return "broken_streetlight"
        if (
            "road obstruction" in label
            or "obstructing" in label
            or "obstruction" in label
            or "fallen tree" in label
            or "tree" in label
            or "vehicle" in label
            or "barrier" in label
            or "debris" in label
            or "block" in label
            or "object obstructing road" in label
        ):
            return "road_obstruction"
        return None

    @staticmethod
    def _build_summary(detections: list[dict]) -> dict:
        summary = {class_name: False for class_name in ROAD_ISSUE_CLASSES}
        for detection in detections:
            class_name = str(detection.get("class", "")).strip()
            if class_name in summary:
                summary[class_name] = True
        return summary

    @staticmethod
    def _determine_priority(summary: dict) -> str:
        if summary.get("pothole") or summary.get("water_logging"):
            return "HIGH"
        if summary.get("road_obstruction"):
            return "MEDIUM"
        if summary.get("broken_streetlight"):
            return "LOW"
        return "LOW"

    @staticmethod
    def _determine_recommended_action(priority: str, summary: dict) -> str:
        if not any(bool(value) for value in summary.values()):
            return "No immediate action required"
        return RECOMMENDED_ACTIONS.get(priority, "Review detected issue")

    @staticmethod
    def _safe_float(value: Any) -> float:
        try:
            return float(value)
        except (TypeError, ValueError):
            return 0.0

    def _deduplicate_detections(self, detections: list[dict]) -> list[dict]:
        ranked = sorted(
            (
                detection
                for detection in detections
                if self._safe_float(detection.get("confidence")) >= self._minimum_confidence_for_backend(
                    str(detection.get("backend", ""))
                )
            ),
            key=lambda item: self._safe_float(item.get("confidence")),
            reverse=True,
        )

        unique: list[dict] = []
        for detection in ranked:
            if any(self._is_duplicate_detection(detection, existing) for existing in unique):
                continue
            unique.append(detection)
        return unique

    def _is_duplicate_detection(self, first: dict, second: dict) -> bool:
        if first.get("class") != second.get("class"):
            return False
        return self._bbox_iou(first.get("bbox", {}), second.get("bbox", {})) >= self._duplicate_iou_threshold(
            str(first.get("class", "")),
            str(first.get("backend", "")),
            str(second.get("backend", "")),
        )

    @staticmethod
    def _bbox_iou(first: dict, second: dict) -> float:
        fx1 = float(first.get("x", 0.0))
        fy1 = float(first.get("y", 0.0))
        fx2 = fx1 + float(first.get("width", 0.0))
        fy2 = fy1 + float(first.get("height", 0.0))

        sx1 = float(second.get("x", 0.0))
        sy1 = float(second.get("y", 0.0))
        sx2 = sx1 + float(second.get("width", 0.0))
        sy2 = sy1 + float(second.get("height", 0.0))

        inter_x1 = max(fx1, sx1)
        inter_y1 = max(fy1, sy1)
        inter_x2 = min(fx2, sx2)
        inter_y2 = min(fy2, sy2)

        inter_width = max(0.0, inter_x2 - inter_x1)
        inter_height = max(0.0, inter_y2 - inter_y1)
        intersection = inter_width * inter_height
        if intersection <= 0:
            return 0.0

        first_area = max(0.0, fx2 - fx1) * max(0.0, fy2 - fy1)
        second_area = max(0.0, sx2 - sx1) * max(0.0, sy2 - sy1)
        union = first_area + second_area - intersection
        if union <= 0:
            return 0.0
        return intersection / union

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

        if width > image_width * 0.85 or height > image_height * 0.85:
            return False

        area_ratio = (width * height) / float(image_width * image_height)
        aspect_ratio = height / width
        center_y_ratio = ((y1 + y2) / 2.0) / float(image_height)

        if label == "pothole":
            return (
                center_y_ratio >= 0.40
                and 0.015 <= area_ratio <= 0.20
                and width >= image_width * 0.05
                and height >= image_height * 0.04
            )
        if label == "water_logging":
            return (
                center_y_ratio >= 0.50
                and area_ratio >= 0.08
                and width >= image_width * 0.18
            )
        if label == "road_obstruction":
            return center_y_ratio >= 0.25 and area_ratio >= 0.002
        if label == "broken_streetlight":
            return (
                aspect_ratio >= 1.80
                and area_ratio <= 0.12
                and height >= image_height * 0.08
            )
        return True

    @staticmethod
    def _model_usage_label(roboflow_detections: list[dict], local_detections: list[dict]) -> str:
        if roboflow_detections and local_detections:
            return "roboflow+local"
        if roboflow_detections:
            return "roboflow"
        if local_detections:
            return "local"
        return "none"

    @staticmethod
    def _minimum_confidence_for_backend(backend: str) -> float:
        if backend == "roboflow":
            return ROBOFLOW_CONF_THRESHOLD
        if backend == "local_yolo":
            return LOCAL_YOLO_CONF_THRESHOLD
        return LOCAL_GROUNDING_DINO_CONF_THRESHOLD

    @staticmethod
    def _duplicate_iou_threshold(
        class_name: str,
        first_backend: str,
        second_backend: str,
    ) -> float:
        if class_name == "pothole" and (
            first_backend == "grounding_dino" or second_backend == "grounding_dino"
        ):
            return 0.35
        return 0.50


def _primary_class_from_summary(summary: dict) -> str | None:
    for class_name in ROAD_ISSUE_CLASSES:
        if summary.get(class_name):
            return class_name
    return None


def format_for_flutter(result: dict) -> dict:
    summary = result.get("summary", {})
    detections = result.get("detections", [])
    priority = str(result.get("priority") or "LOW").upper()
    primary_class = _primary_class_from_summary(summary)
    display_issue = DISPLAY_LABELS.get(primary_class or "", "Road OK")
    confidence = max(
        (float(detection.get("confidence", 0.0)) for detection in detections),
        default=0.0,
    )
    boxes = [
        detection.get("bbox", {"x": 0.0, "y": 0.0, "width": 0.0, "height": 0.0})
        for detection in detections
    ]

    return {
        "summary": summary,
        "detections": detections,
        "priority": priority,
        "recommended_action": result.get(
            "recommended_action",
            "No immediate action required",
        ),
        "issue": display_issue,
        "severity": priority.lower(),
        "confidence": round(confidence, 4),
        "boxes": boxes,
    }


def get_hybrid_detector(
    weights_path: str,
    conf: float = YOLO_CONF_THRESHOLD,
) -> HybridRoadDetector:
    cache_key = (str(Path(weights_path).resolve()), conf)
    if cache_key not in _DETECTORS:
        _DETECTORS[cache_key] = HybridRoadDetector(weights_path=weights_path, conf=conf)
    return _DETECTORS[cache_key]


def detect_road_issues(image_path: str) -> dict:
    detector = get_hybrid_detector(str(get_default_weights_path()))
    return detector.detect_road_issues(image_path)
