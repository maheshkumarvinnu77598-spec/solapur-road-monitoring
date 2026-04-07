from ultralytics import YOLO

# Load your trained model
model = YOLO("models/road_damage_weights/best.pt")

def detect_with_yolo(image):

    results = model(image)

    detections = []

    for r in results[0].boxes.data.tolist():
        x1, y1, x2, y2, conf, cls = r

        detections.append({
            "bbox": [x1, y1, x2, y2],
            "confidence": float(conf),
            "class": int(cls)
        })

    return detections