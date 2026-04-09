from __future__ import annotations

import json
import os
import time
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any

import cv2
from PIL import Image
import torch

try:
    from transformers import AutoModelForZeroShotObjectDetection, AutoProcessor
except ImportError:
    AutoModelForZeroShotObjectDetection = None  # type: ignore[assignment]
    AutoProcessor = None  # type: ignore[assignment]

try:
    from inference_sdk import InferenceHTTPClient
except ImportError:
    InferenceHTTPClient = None  # type: ignore[assignment]


BASE_DIR = Path(__file__).resolve().parent
DEFAULT_WORKFLOW_IDS = (
    "detect-and-classify",
    "detect-count-and-visualize",
    "detect-and-classify-2",
)
ROBOFLOW_API_URL = os.getenv("ROBOFLOW_API_URL", "https://serverless.roboflow.com")
ROBOFLOW_API_KEY = os.getenv("ROBOFLOW_API_KEY", "").strip()
ROBOFLOW_WORKSPACE_NAME = os.getenv("ROBOFLOW_WORKSPACE_NAME", "tillu-kowkuntla").strip() or "tillu-kowkuntla"
ROBOFLOW_IMAGE_INPUT_NAME = os.getenv("ROBOFLOW_IMAGE_INPUT_NAME", "image").strip() or "image"
ROBOFLOW_USE_CACHE = os.getenv("ROBOFLOW_USE_CACHE", "1").strip() != "0"
POTHOLE_FALLBACK_MODEL_ID = "IDEA-Research/grounding-dino-base"
POTHOLE_FALLBACK_BOX_THRESHOLD = float(os.getenv("POTHOLE_FALLBACK_BOX_THRESHOLD", "0.22"))
POTHOLE_FALLBACK_TEXT_THRESHOLD = float(os.getenv("POTHOLE_FALLBACK_TEXT_THRESHOLD", "0.22"))

ROAD_ISSUE_CLASSES = (
    "pothole",
    "water_logging",
    "road_obstruction",
    "broken_streetlight",
)
CLASS_CONFIDENCE_THRESHOLDS = {
    "pothole": float(os.getenv("ROBOFLOW_POTHOLE_CONFIDENCE", "0.30")),
    "water_logging": float(os.getenv("ROBOFLOW_WATER_LOGGING_CONFIDENCE", "0.40")),
    "road_obstruction": float(os.getenv("ROBOFLOW_ROAD_OBSTRUCTION_CONFIDENCE", "0.40")),
    "broken_streetlight": float(os.getenv("ROBOFLOW_BROKEN_STREETLIGHT_CONFIDENCE", "0.45")),
}
DUPLICATE_IOU_THRESHOLD = float(os.getenv("ROBOFLOW_DUPLICATE_IOU_THRESHOLD", "0.55"))
MAX_BOX_AREA_RATIO = float(os.getenv("ROBOFLOW_MAX_BOX_AREA_RATIO", "0.90"))

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
DEBUG_LOG_PATH = Path("runs") / "ml_debug_log.json"
_DETECTORS: dict[tuple[str, float], "HybridRoadDetector"] = {}


@dataclass(frozen=True)
class WorkflowConfig:
    workflow_id: str


WORKFLOW_CONFIGS = tuple(WorkflowConfig(workflow_id=workflow_id) for workflow_id in DEFAULT_WORKFLOW_IDS)


def get_default_weights_path() -> Path:
    """Legacy helper kept for import compatibility with the existing backend."""
    return BASE_DIR / "best.pt"


class HybridRoadDetector:
    """Compatibility wrapper that now runs trained Roboflow workflows only."""

    def __init__(
        self,
        weights_path: str | None = None,
        conf: float = 0.0,
    ) -> None:
        self.weights_path = Path(weights_path) if weights_path is not None else get_default_weights_path()
        self.conf = conf
        self.workspace_name = ROBOFLOW_WORKSPACE_NAME
        self.workflow_ids = self._resolve_workflow_ids()
        self.roboflow_client = self._load_roboflow_client()
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        self._fallback_processor = None
        self._fallback_model = None

        print(f"[ML] Workspace: {self.workspace_name}")
        print(f"[ML] Workflows: {', '.join(self.workflow_ids) if self.workflow_ids else 'none'}")

    def detect(self, image_path: str) -> dict:
        return self.detect_road_issues(image_path)

    def detect_road_issues(self, image_path: str) -> dict:
        image_name = Path(image_path).name
        started_at = time.perf_counter()
        image_size = self._load_image_size(image_path)

        detections = self._run_workflows(image_path, image_size)
        if not any(detection.get("class") == "pothole" for detection in detections):
            detections.extend(self._run_pothole_fallback(image_path, image_size))
        detections = self._deduplicate_detections(detections)

        summary = self._build_summary(detections)
        priority = self._determine_priority(summary)
        recommended_action = self._determine_recommended_action(priority, summary)

        result = {
            "summary": summary,
            "detections": detections,
            "priority": priority,
            "recommended_action": recommended_action,
        }

        print(f"[ML] Final detections: {len(detections)}")
        print(f"[ML] Priority: {priority}")

        self.append_debug_log(
            image_name=image_name,
            model_used=self._model_usage_label(detections),
            detections_count=len(detections),
            processing_time_ms=round((time.perf_counter() - started_at) * 1000),
        )
        return result

    def _load_roboflow_client(self):
        if InferenceHTTPClient is None:
            print("[ML WARNING] inference_sdk is not installed. Roboflow disabled.")
            return None
        if not ROBOFLOW_API_KEY:
            print("[ML WARNING] ROBOFLOW_API_KEY not set. Roboflow disabled.")
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

    @staticmethod
    def _resolve_workflow_ids() -> tuple[str, ...]:
        configured = os.getenv("ROBOFLOW_WORKFLOW_IDS", "").strip()
        if not configured:
            return tuple(config.workflow_id for config in WORKFLOW_CONFIGS)

        workflow_ids = tuple(
            workflow_id.strip()
            for workflow_id in configured.split(",")
            if workflow_id.strip()
        )
        return workflow_ids or tuple(config.workflow_id for config in WORKFLOW_CONFIGS)

    @staticmethod
    def _load_image_size(image_path: str) -> tuple[int, int]:
        try:
            with Image.open(image_path) as image:
                size = image.size
        except Exception as error:
            raise RuntimeError(f"Failed to read image: {error}") from error

        print("[ML] Image size:", size)
        return size

    def _run_workflows(
        self,
        image_path: str,
        image_size: tuple[int, int],
    ) -> list[dict]:
        if self.roboflow_client is None or not self.workflow_ids:
            return []

        detections: list[dict] = []
        for workflow_id in self.workflow_ids:
            try:
                print(f"[ML] Running workflow: {workflow_id}")
                workflow_output = self.roboflow_client.run_workflow(
                    workspace_name=self.workspace_name,
                    workflow_id=workflow_id,
                    images={ROBOFLOW_IMAGE_INPUT_NAME: image_path},
                    use_cache=ROBOFLOW_USE_CACHE,
                )
                detections.extend(
                    self._extract_workflow_detections(
                        workflow_output=workflow_output,
                        workflow_id=workflow_id,
                        image_size=image_size,
                    )
                )
            except Exception as error:
                print(f"[ML WARNING] Workflow {workflow_id} failed: {error}")

        return detections

    def _run_pothole_fallback(
        self,
        image_path: str,
        image_size: tuple[int, int],
    ) -> list[dict]:
        if not self._looks_like_road_scene(image_path):
            return []

        components = self._get_pothole_fallback_components()
        if components is None:
            return []

        processor, model = components
        prompt = (
            "large pothole in asphalt road. "
            "pothole filled with water on road. "
            "damaged road surface pothole."
        )

        try:
            image = Image.open(image_path).convert("RGB")
        except Exception as error:
            print(f"[ML WARNING] Failed to load image for pothole fallback: {error}")
            return []

        inputs = processor(images=image, text=prompt, return_tensors="pt")
        inputs = {
            key: value.to(self.device) if hasattr(value, "to") else value
            for key, value in inputs.items()
        }

        with torch.no_grad():
            outputs = model(**inputs)

        results = processor.post_process_grounded_object_detection(
            outputs,
            inputs["input_ids"],
            threshold=POTHOLE_FALLBACK_BOX_THRESHOLD,
            text_threshold=POTHOLE_FALLBACK_TEXT_THRESHOLD,
            target_sizes=[image.size[::-1]],
        )

        detections: list[dict] = []
        if not results:
            return detections

        result = results[0]
        text_labels = result.get("text_labels")
        if text_labels is None:
            text_labels = [self._decode_fallback_label(label, processor) for label in result["labels"]]

        for score, raw_label, box in zip(result["scores"], text_labels, result["boxes"]):
            confidence = float(score)
            normalized_label = self._normalize_class_name(raw_label)
            if normalized_label != "pothole":
                continue
            if confidence < 0.26:
                continue

            bbox = self._normalize_xyxy_box(box.tolist(), image_size)
            if bbox is None or not self._passes_pothole_fallback_filter(bbox, image_size):
                continue

            detections.append(
                self._make_detection(
                    class_name="pothole",
                    confidence=max(confidence, 0.51),
                    bbox=bbox,
                    workflow_id="pothole_fallback",
                )
            )

        if detections:
            print(f"[ML] Pothole fallback detections: {len(detections)}")
        return detections

    def _get_pothole_fallback_components(self):
        if self._fallback_processor is not None and self._fallback_model is not None:
            return self._fallback_processor, self._fallback_model
        if AutoProcessor is None or AutoModelForZeroShotObjectDetection is None:
            print("[ML WARNING] transformers not installed. Pothole fallback disabled.")
            return None

        try:
            processor = AutoProcessor.from_pretrained(
                POTHOLE_FALLBACK_MODEL_ID,
                local_files_only=True,
            )
            model = AutoModelForZeroShotObjectDetection.from_pretrained(
                POTHOLE_FALLBACK_MODEL_ID,
                local_files_only=True,
            )
        except Exception:
            try:
                processor = AutoProcessor.from_pretrained(POTHOLE_FALLBACK_MODEL_ID)
                model = AutoModelForZeroShotObjectDetection.from_pretrained(POTHOLE_FALLBACK_MODEL_ID)
            except Exception as error:
                print(f"[ML WARNING] Failed to load pothole fallback model: {error}")
                return None

        model = model.to(self.device)
        model.eval()
        self._fallback_processor = processor
        self._fallback_model = model
        print("[ML] Pothole fallback model loaded")
        return processor, model

    def _extract_workflow_detections(
        self,
        workflow_output: Any,
        workflow_id: str,
        image_size: tuple[int, int],
    ) -> list[dict]:
        detections: list[dict] = []

        def visit(node: Any) -> None:
            if isinstance(node, dict):
                if self._looks_like_detection(node):
                    raw_label = self._extract_raw_label(node)
                    normalized_label = self._normalize_class_name(raw_label)
                    confidence = self._extract_confidence(node)
                    bbox = self._normalize_bbox(node, image_size)

                    if (
                        normalized_label in ROAD_ISSUE_CLASSES
                        and confidence >= self._minimum_confidence_for_class(normalized_label)
                        and bbox is not None
                    ):
                        detections.append(
                            self._make_detection(
                                class_name=normalized_label,
                                confidence=confidence,
                                bbox=bbox,
                                workflow_id=workflow_id,
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

    @staticmethod
    def _looks_like_detection(node: dict[str, Any]) -> bool:
        has_label = bool(HybridRoadDetector._extract_raw_label(node))
        has_confidence = any(
            key in node for key in ("confidence", "score", "confidence_score")
        )
        has_bbox = HybridRoadDetector._extract_bbox(node) is not None
        return has_label and has_confidence and has_bbox

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
    def _extract_confidence(node: dict[str, Any]) -> float:
        for key in ("confidence", "score", "confidence_score"):
            if key in node:
                return HybridRoadDetector._safe_float(node.get(key))
        return 0.0

    @staticmethod
    def _extract_bbox(node: dict[str, Any]) -> dict[str, float] | None:
        if {"x", "y", "width", "height"}.issubset(node):
            x = HybridRoadDetector._safe_float(node["x"])
            y = HybridRoadDetector._safe_float(node["y"])
            width = HybridRoadDetector._safe_float(node["width"])
            height = HybridRoadDetector._safe_float(node["height"])
            return {
                "x": x - (width / 2.0),
                "y": y - (height / 2.0),
                "width": width,
                "height": height,
            }
        if {"x1", "y1", "x2", "y2"}.issubset(node):
            x1 = HybridRoadDetector._safe_float(node["x1"])
            y1 = HybridRoadDetector._safe_float(node["y1"])
            x2 = HybridRoadDetector._safe_float(node["x2"])
            y2 = HybridRoadDetector._safe_float(node["y2"])
            return {
                "x": x1,
                "y": y1,
                "width": max(0.0, x2 - x1),
                "height": max(0.0, y2 - y1),
            }
        if {"left", "top", "right", "bottom"}.issubset(node):
            left = HybridRoadDetector._safe_float(node["left"])
            top = HybridRoadDetector._safe_float(node["top"])
            right = HybridRoadDetector._safe_float(node["right"])
            bottom = HybridRoadDetector._safe_float(node["bottom"])
            return {
                "x": left,
                "y": top,
                "width": max(0.0, right - left),
                "height": max(0.0, bottom - top),
            }
        return None

    def _normalize_bbox(
        self,
        node: dict[str, Any],
        image_size: tuple[int, int],
    ) -> dict[str, float] | None:
        raw_bbox = self._extract_bbox(node)
        if raw_bbox is None:
            return None

        image_width, image_height = image_size
        x = max(0.0, min(self._safe_float(raw_bbox["x"]), float(image_width)))
        y = max(0.0, min(self._safe_float(raw_bbox["y"]), float(image_height)))
        width = max(0.0, self._safe_float(raw_bbox["width"]))
        height = max(0.0, self._safe_float(raw_bbox["height"]))

        if x + width > image_width:
            width = max(0.0, float(image_width) - x)
        if y + height > image_height:
            height = max(0.0, float(image_height) - y)
        if width <= 1.0 or height <= 1.0:
            return None

        area_ratio = (width * height) / max(1.0, float(image_width * image_height))
        if area_ratio > MAX_BOX_AREA_RATIO:
            return None

        return {
            "x": round(x, 2),
            "y": round(y, 2),
            "width": round(width, 2),
            "height": round(height, 2),
        }

    def _normalize_xyxy_box(
        self,
        bbox: list[float],
        image_size: tuple[int, int],
    ) -> dict[str, float] | None:
        if len(bbox) != 4:
            return None

        image_width, image_height = image_size
        x1, y1, x2, y2 = [self._safe_float(value) for value in bbox]
        x1 = max(0.0, min(x1, float(image_width)))
        y1 = max(0.0, min(y1, float(image_height)))
        x2 = max(0.0, min(x2, float(image_width)))
        y2 = max(0.0, min(y2, float(image_height)))

        width = max(0.0, x2 - x1)
        height = max(0.0, y2 - y1)
        if width <= 1.0 or height <= 1.0:
            return None

        return {
            "x": round(x1, 2),
            "y": round(y1, 2),
            "width": round(width, 2),
            "height": round(height, 2),
        }

    @staticmethod
    def _make_detection(
        class_name: str,
        confidence: float,
        bbox: dict[str, float],
        workflow_id: str,
    ) -> dict:
        _ = workflow_id
        return {
            "class": class_name,
            "confidence": round(float(confidence), 4),
            "bbox": bbox,
        }

    @staticmethod
    def _normalize_class_name(raw_label: object) -> str | None:
        label = str(raw_label).lower().replace("_", " ").replace("-", " ").strip()
        label = " ".join(label.split())

        if not label:
            return None
        if "pothole" in label or "road damage" in label or "hole" in label or "crack" in label:
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
        ):
            return "road_obstruction"
        return None

    @staticmethod
    def _minimum_confidence_for_class(class_name: str) -> float:
        return CLASS_CONFIDENCE_THRESHOLDS.get(class_name, 0.40)

    @staticmethod
    def _decode_fallback_label(label: object, processor: Any) -> str:
        if isinstance(label, str):
            return label

        try:
            raw_value = int(label.item()) if hasattr(label, "item") else int(label)
        except Exception:
            return str(label)

        try:
            if hasattr(processor, "decode"):
                return processor.decode([raw_value], skip_special_tokens=True).strip()
            return processor.tokenizer.decode([raw_value], skip_special_tokens=True).strip()
        except Exception:
            return str(raw_value)

    @staticmethod
    def _passes_pothole_fallback_filter(
        bbox: dict[str, float],
        image_size: tuple[int, int],
    ) -> bool:
        image_width, image_height = image_size
        width = HybridRoadDetector._safe_float(bbox.get("width"))
        height = HybridRoadDetector._safe_float(bbox.get("height"))
        x = HybridRoadDetector._safe_float(bbox.get("x"))
        y = HybridRoadDetector._safe_float(bbox.get("y"))

        if width <= 0.0 or height <= 0.0:
            return False

        area_ratio = (width * height) / max(1.0, float(image_width * image_height))
        center_y_ratio = (y + (height / 2.0)) / max(1.0, float(image_height))
        aspect_ratio = max(width, height) / max(1.0, min(width, height))
        within_frame = x >= 0.0 and y >= 0.0 and (x + width) <= image_width and (y + height) <= image_height

        return (
            within_frame
            and center_y_ratio >= 0.42
            and 0.01 <= area_ratio <= 0.18
            and width >= image_width * 0.08
            and height >= image_height * 0.05
            and aspect_ratio <= 3.6
        )

    @staticmethod
    def _looks_like_road_scene(image_path: str) -> bool:
        image = cv2.imread(image_path)
        if image is None:
            return False

        hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        height = gray.shape[0]
        lower_start = int(height * 0.45)
        lower_hsv = hsv[lower_start:, :, :]
        lower_gray = gray[lower_start:, :]
        if lower_hsv.size == 0 or lower_gray.size == 0:
            return False

        mean_saturation = float(lower_hsv[:, :, 1].mean())
        edges = cv2.Canny(lower_gray, 80, 160)
        edge_ratio = float((edges > 0).mean())

        return mean_saturation <= 65.0 and edge_ratio >= 0.08

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

    def _deduplicate_detections(self, detections: list[dict]) -> list[dict]:
        ranked = sorted(
            detections,
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
        iou_threshold = 0.50 if first.get("class") == "pothole" else DUPLICATE_IOU_THRESHOLD
        return self._bbox_iou(first.get("bbox", {}), second.get("bbox", {})) >= iou_threshold

    @staticmethod
    def _bbox_iou(first: dict, second: dict) -> float:
        fx1 = HybridRoadDetector._safe_float(first.get("x", 0.0))
        fy1 = HybridRoadDetector._safe_float(first.get("y", 0.0))
        fx2 = fx1 + HybridRoadDetector._safe_float(first.get("width", 0.0))
        fy2 = fy1 + HybridRoadDetector._safe_float(first.get("height", 0.0))

        sx1 = HybridRoadDetector._safe_float(second.get("x", 0.0))
        sy1 = HybridRoadDetector._safe_float(second.get("y", 0.0))
        sx2 = sx1 + HybridRoadDetector._safe_float(second.get("width", 0.0))
        sy2 = sy1 + HybridRoadDetector._safe_float(second.get("height", 0.0))

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
    def _safe_float(value: Any) -> float:
        try:
            return float(value)
        except (TypeError, ValueError):
            return 0.0

    @staticmethod
    def _model_usage_label(detections: list[dict]) -> str:
        if not detections:
            return "roboflow:none"
        return "roboflow:merged"

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
    conf: float = 0.0,
) -> HybridRoadDetector:
    cache_key = (str(Path(weights_path).resolve()), conf)
    if cache_key not in _DETECTORS:
        _DETECTORS[cache_key] = HybridRoadDetector(weights_path=weights_path, conf=conf)
    return _DETECTORS[cache_key]


def detect_road_issues(image_path: str) -> dict:
    detector = get_hybrid_detector(str(get_default_weights_path()))
    return detector.detect_road_issues(image_path)
