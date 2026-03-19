"""
Flask Pothole Detection API Server
==================================

Example Flask backend for AI pothole detection.
This server receives images and returns pothole predictions.

SETUP:
------
1. Install dependencies:
   pip install flask flask-cors pillow werkzeug

2. Run the server:
   python app.py

   By default runs on http://localhost:5000

3. For Android emulator access:
   - Server will be accessible at http://10.0.2.2:5000 from emulator

4. For physical device access:
   - Replace localhost with your machine's IP (e.g., 192.168.x.x)
   - Ensure device and machine are on same WiFi

API ENDPOINTS:
--------------

POST /predict
  Analyzes an image for pothole detection
  
  Request:
    - Body: multipart/form-data
    - File field: "file" (image file)
  
  Response (200 OK):
    {
      "prediction": "pothole" or "normal",
      "confidence": 0.95,
      "model_version": "v1.0.0",
      "processing_time_ms": 250
    }
  
  Error Response (400/500):
    {
      "error": "Error message",
      "status": "error"
    }

GET /health
  Health check endpoint
  
  Response (200 OK):
    {
      "status": "healthy",
      "model_loaded": true,
      "api_version": "1.0"
    }

INTEGRATION WITH FLUTTER APP:
-----------------------------

The Flutter app will send images to this endpoint and expect JSON responses.
Make sure the Flask server is running before testing on the Flutter app.
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import io
import time
from werkzeug.utils import secure_filename
from PIL import Image
import random

# ============================================================================
# CONFIGURATION
# ============================================================================

app = Flask(__name__)

# Enable CORS for Flutter requests
CORS(app)

# Configuration
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file size
app.config['UPLOAD_FOLDER'] = 'uploads'
ALLOWED_EXTENSIONS = {'jpg', 'jpeg', 'png', 'gif', 'bmp'}
API_VERSION = '1.0.0'

# Create uploads directory if it doesn't exist
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

# ============================================================================
# MOCK MODEL (Replace with real ML model)
# ============================================================================

class PotholeDetectionModel:
    """
    Mock pothole detection model.
    Replace this with your actual ML model (YOLOv5, YOLOv8, etc.)
    """
    
    def __init__(self):
        self.model_name = "YOLOv5-Pothole"
        self.version = "1.0.0"
        self.loaded = True
        
    def predict(self, image_path):
        """
        Predict pothole in image.
        
        INTEGRATION WITH REAL MODEL:
        ----------------------------
        Replace this mock with:
        
        from ultralytics import YOLO
        
        class PotholeDetectionModel:
            def __init__(self):
                self.model = YOLO('best.pt')  # Load your trained model
                self.model_name = "YOLOv8-Pothole"
                self.loaded = True
            
            def predict(self, image_path):
                results = self.model.predict(source=image_path, conf=0.5)
                
                if len(results) == 0:
                    return False, 0.0
                
                r = results[0]
                if len(r.boxes) == 0:
                    return False, 0.0
                
                # Get highest confidence detection
                confidences = r.boxes.conf
                max_conf = float(confidences.max())
                
                # If confidence > 0.5, predict pothole
                return max_conf > 0.5, max_conf
        """
        
        # MOCK IMPLEMENTATION
        # For demo purposes, analyzes image properties
        try:
            img = Image.open(image_path)
            
            # Simple mock: check image properties
            # In real model, would run ML inference
            width, height = img.size
            
            # Mock logic: larger images more likely to have potholes
            # (This is just for demo - replace with real model)
            size_score = min((width * height) / (1280 * 720), 1.0)
            
            # Random variation for testing UI
            base_confidence = 0.5 + (size_score * 0.3) + random.uniform(-0.1, 0.2)
            confidence = min(max(base_confidence, 0.0), 1.0)
            
            # Predict pothole if confidence > 0.5
            is_pothole = confidence > 0.5
            
            return is_pothole, confidence
            
        except Exception as e:
            print(f"Prediction error: {e}")
            return False, 0.0


# Initialize model
model = PotholeDetectionModel()

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def allowed_file(filename):
    """Check if file extension is allowed"""
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


def process_image_for_model(image_path):
    """
    Preprocess image before sending to model.
    
    For real model, might include:
    - Resizing to model input size
    - Normalization
    - Data augmentation
    """
    try:
        img = Image.open(image_path)
        
        # Resize to standard size if needed
        # Standard size depends on your model
        # (e.g., YOLOv5 typically uses 640x640)
        MAX_SIZE = 640
        img.thumbnail((MAX_SIZE, MAX_SIZE), Image.Resampling.LANCZOS)
        
        # Convert to RGB if needed
        if img.mode != 'RGB':
            img = img.convert('RGB')
        
        return img
    except Exception as e:
        print(f"Image processing error: {e}")
        return None


# ============================================================================
# API ENDPOINTS
# ============================================================================

@app.route('/predict', methods=['POST'])
def predict():
    """
    POST /predict - Analyze image for pothole detection
    
    Expects multipart/form-data with "file" field containing image
    
    Returns JSON with prediction results
    """
    
    start_time = time.time()
    
    # Check if file is in request
    if 'file' not in request.files:
        return jsonify({
            'error': 'No file part in request',
            'status': 'error'
        }), 400
    
    file = request.files['file']
    
    # Check if file is selected
    if file.filename == '':
        return jsonify({
            'error': 'No file selected',
            'status': 'error'
        }), 400
    
    # Check if file is allowed
    if not allowed_file(file.filename):
        return jsonify({
            'error': f'Invalid file type. Allowed: {", ".join(ALLOWED_EXTENSIONS)}',
            'status': 'error'
        }), 400
    
    try:
        # Save uploaded file temporarily
        filename = secure_filename(file.filename)
        timestamp = int(time.time() * 1000)
        temp_filename = f"{timestamp}_{filename}"
        file_path = os.path.join(app.config['UPLOAD_FOLDER'], temp_filename)
        
        file.save(file_path)
        
        # Process image
        img = process_image_for_model(file_path)
        if img is None:
            return jsonify({
                'error': 'Failed to process image',
                'status': 'error'
            }), 400
        
        # Run prediction
        is_pothole, confidence = model.predict(file_path)
        
        # Prepare response
        processing_time = (time.time() - start_time) * 1000  # milliseconds
        
        response = {
            'prediction': 'pothole' if is_pothole else 'normal',
            'confidence': float(confidence),
            'model_version': model.version,
            'processing_time_ms': round(processing_time, 2),
            'timestamp': timestamp
        }
        
        # Clean up temp file
        try:
            os.remove(file_path)
        except:
            pass
        
        return jsonify(response), 200
        
    except Exception as e:
        print(f"Prediction error: {e}")
        return jsonify({
            'error': str(e),
            'status': 'error',
            'processing_time_ms': round((time.time() - start_time) * 1000, 2)
        }), 500


@app.route('/health', methods=['GET'])
def health():
    """
    GET /health - Health check endpoint
    
    Returns server health status
    """
    
    return jsonify({
        'status': 'healthy',
        'model_loaded': model.loaded,
        'model_name': model.model_name,
        'model_version': model.version,
        'api_version': API_VERSION,
        'timestamp': int(time.time() * 1000)
    }), 200


@app.route('/', methods=['GET'])
def index():
    """Root endpoint - API info"""
    
    return jsonify({
        'name': 'Pothole Detection API',
        'version': API_VERSION,
        'endpoints': {
            'POST /predict': 'Analyze image for pothole detection',
            'GET /health': 'Health check',
            '': ''
        },
        'model': {
            'name': model.model_name,
            'version': model.version,
            'loaded': model.loaded
        }
    }), 200


# ============================================================================
# ERROR HANDLERS
# ============================================================================

@app.errorhandler(413)
def request_entity_too_large(error):
    """Handle files that are too large"""
    return jsonify({
        'error': 'File too large (max 16MB)',
        'status': 'error'
    }), 413


@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors"""
    return jsonify({
        'error': 'Endpoint not found',
        'status': 'error',
        'available_endpoints': ['/predict', '/health', '/']
    }), 404


@app.errorhandler(500)
def server_error(error):
    """Handle server errors"""
    return jsonify({
        'error': 'Internal server error',
        'status': 'error'
    }), 500


# ============================================================================
# MAIN
# ============================================================================

if __name__ == '__main__':
    print("=" * 60)
    print("Pothole Detection API Server")
    print("=" * 60)
    print(f"\n📍 API Version: {API_VERSION}")
    print(f"🤖 Model: {model.model_name} v{model.version}")
    print(f"✅ Model Loaded: {model.loaded}")
    print("\n📡 Starting server on http://localhost:5000")
    print("\n📋 Available endpoints:")
    print("  • POST   /predict     - Analyze image")
    print("  • GET    /health      - Health check")
    print("  • GET    /            - API info")
    print("\n🔗 For Android emulator: http://10.0.2.2:5000")
    print("🔗 For physical device: http://<YOUR_IP>:5000")
    print("\n⚠️  CORS enabled for Flutter app requests")
    print("\n📚 Documentation: See AI_INTEGRATION_GUIDE.dart")
    print("\n" + "=" * 60 + "\n")
    
    # Run development server
    # For production, use gunicorn or similar:
    # gunicorn -w 4 -b 0.0.0.0:5000 app.py
    app.run(
        host='0.0.0.0',  # Listen on all interfaces
        port=5000,
        debug=True,
        use_reloader=True
    )
