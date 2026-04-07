from grounding_dino_model import detect_with_dino
from fallback_yolo_model import detect_with_yolo

CONFIDENCE_THRESHOLD = 0.5


def analyze_image(image):

    # Run primary model
    dino_results = detect_with_dino(image)

    if len(dino_results) > 0 and len(dino_results[0]["scores"]) > 0:

        score = float(dino_results[0]["scores"][0])

        if score > CONFIDENCE_THRESHOLD:

            return {
                "source": "grounding_dino",
                "detections": dino_results
            }

    # fallback model
    yolo_results = detect_with_yolo(image)

    return {
        "source": "fallback_yolo",
        "detections": yolo_results
    }