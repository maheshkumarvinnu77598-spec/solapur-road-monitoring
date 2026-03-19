# 🚗 AI Pothole Detection Integration

Complete guide to integrate Flask-based AI pothole detection into your Solapur Road Monitoring Flutter app.

---

## 📋 Table of Contents

1. [Quick Start](#quick-start)
2. [Architecture](#architecture)
3. [File Overview](#file-overview)
4. [Installation & Setup](#installation--setup)
5. [API Reference](#api-reference)
6. [Integration Steps](#integration-steps)
7. [UI Components](#ui-components)
8. [Testing](#testing)
9. [Troubleshooting](#troubleshooting)
10. [Advanced Configuration](#advanced-configuration)

---

## 🚀 Quick Start

### For Flutter Developers

```dart
import 'package:solapur_road_monitoring/services/flask_pothole_service.dart';
import 'package:solapur_road_monitoring/reporting/ai_reporting_integration.dart';

// 1. Initialize AI service
final aiIntegration = AiReportingIntegration(
  config: const AiIntegrationConfig(
    enabled: true,
    autoSelectPotholeCategory: true,
    showResultCard: true,
  ),
);

// 2. Analyze image
final result = await aiIntegration.analyzeImage(
  imageFile: capturedImage,
);

// 3. Handle result
if (result != null && result.detection.isPothole) {
  // Auto-select pothole category and set high priority
  setState(() {
    selectedCategory = 'Pothole';
    priority = 'High';
  });
}

// 4. Show result UI
if (result != null) {
  showWidget(
    aiIntegration.buildResultWidget(result),
  );
}
```

### For Backend Developers (Flask)

```bash
# 1. Install dependencies
pip install flask flask-cors pillow

# 2. Run Flask server
python ai/flask_app.py

# Server will be available at:
# - Emulator: http://10.0.2.2:5000
# - Local: http://localhost:5000
```

---

## 🏗️ Architecture

### System Flow

```
User captures image
         ↓
   Image compressed locally
         ↓
   Sent to Flask API (POST /predict)
         ↓
Flask model inference (ML-based detection)
         ↓
   Returns JSON response:
   {
     "prediction": "pothole|normal",
     "confidence": 0.95,
     "processing_time_ms": 250
   }
         ↓
UI displays result card (animated)
         ↓
Auto-apply suggestions if high confidence
         ↓
User submits report with AI insights
```

### Component Diagram

```
Flutter App
├── Image Capture (ImagePicker)
│
├── Image Compression (flutter_image_compress)
│
├── FlaskPotholeService
│   ├── Device detection (emulator/device)
│   ├── HTTP multipart request
│   └── JSON response parsing
│
├── AiReportingIntegration
│   ├── Config management
│   ├── Error handling
│   └── UI widget generation
│
├── UI Components
│   ├── AiPotholeResultCard (animated display)
│   ├── AiLoadingCard (analysis in progress)
│   └── AiErrorCard (error state)
│
└── Report Submission
    ├── Category auto-selection
    ├── Priority auto-setting
    └── Firebase upload with AI metadata

        ↓ ↓ ↓ NETWORK ↓ ↓ ↓

Flask Backend (ai/flask_app.py)
├── /predict (POST)
│   ├── File validation
│   ├── Image preprocessing
│   ├── ML model inference
│   └── Confidence calculation
│
├── /health (GET)
│   └── Status check
│
└── Model (YOLOv5/YOLOv8)
    ├── Pothole detection
    ├── Confidence scoring
    └── Box coordinates (optional)
```

---

## 📁 File Overview

### New Files Created

#### 1. **lib/services/flask_pothole_service.dart**
Core service for Flask API communication
- `FlaskPotholeService` - Main service class
- `PotholeDetectionResult` - Response model
- Device detection (emulator/device)
- Error handling with timeouts
- Connection testing

#### 2. **lib/ui_theme/ai_result_card.dart**
Beautiful UI components for displaying results
- `AiPotholeResultCard` - Animated result display
- `AiLoadingCard` - Loading indicator
- `AiErrorCard` - Error state
- Smooth animations with scaling/fading

#### 3. **lib/reporting/ai_reporting_integration.dart**
High-level integration manager
- `AiReportingIntegration` - Main integration class
- `AiIntegrationConfig` - Configuration model
- `AiAnalysisState` - State management
- Widget builders

#### 4. **lib/services/ai_config.dart**
Centralized configuration
- API endpoints and timeouts
- Feature flags
- Environment presets
- Helper functions for config

#### 5. **ai/flask_app.py**
Example Flask backend server
- `/predict` endpoint for pothole detection
- `/health` endpoint for status check
- Mock ML model (replace with real model)
- CORS enabled for Flutter
- File validation and error handling

#### 6. **lib/reporting/AI_INTEGRATION_GUIDE.dart**
Step-by-step integration guide
- Code examples
- Integration points
- Testing tips
- Troubleshooting

---

## ⚙️ Installation & Setup

### Step 1: Add Dependencies to pubspec.yaml

```yaml
dependencies:
  http: ^1.1.0  # Add if not already included
  flutter:
    sdk: flutter
  # ... other dependencies ...
```

Run: `flutter pub get`

### Step 2: Copy Files to Your Project

All files are already created in the correct locations:

```
lib/
  services/
    flask_pothole_service.dart   ← NEW
    ai_config.dart                ← NEW
  ui_theme/
    ai_result_card.dart           ← NEW
  reporting/
    ai_reporting_integration.dart ← NEW
    AI_INTEGRATION_GUIDE.dart     ← NEW (reference only)

ai/
  flask_app.py                    ← NEW (backend)
```

### Step 3: Update report_wizard_screen.dart

Add imports:

```dart
import '../services/flask_pothole_service.dart';
import '../reporting/ai_reporting_integration.dart';
import '../ui_theme/ai_result_card.dart';
```

Add fields in `_ReportWizardScreenState`:

```dart
late final AiReportingIntegration _aiIntegration;
final AiAnalysisState _aiState = AiAnalysisState();
PotholeDetectionResult? _potholeResult;
```

Initialize in `initState()`:

```dart
@override
void initState() {
  super.initState();
  
  // ... existing initState code ...
  
  // Initialize AI integration
  _aiIntegration = AiReportingIntegration(
    config: const AiIntegrationConfig(
      enabled: true,
      autoSelectPotholeCategory: true,
      autoSetHighPriority: true,
      showResultCard: true,
      timeoutSeconds: 30,
    ),
  );
  _aiIntegration.initialize();
}
```

### Step 4: Setup Flask Backend

```bash
# Navigate to project root
cd /path/to/solapur_road_monitoring

# Install Python dependencies
pip install flask flask-cors pillow werkzeug

# Run Flask server
python ai/flask_app.py

# Output should show:
# Pothole Detection API Server
# 📡 Starting server on http://localhost:5000
```

### Step 5: Create Virtual Environment (Recommended)

```bash
# Create virtual environment in ai folder
cd ai
python -m venv venv

# Activate virtual environment
source venv/bin/activate  # macOS/Linux
# OR
venv\Scripts\activate  # Windows

# Install dependencies in virtual environment
pip install flask flask-cors pillow werkzeug

# Run Flask server
python flask_app.py
```

---

## 📡 API Reference

### Flask Endpoints

#### POST /predict

Analyzes an image for pothole detection.

**Request:**
```
POST http://10.0.2.2:5000/predict (Android emulator)
POST http://localhost:5000/predict (iOS simulator)
POST http://<device-ip>:5000/predict (physical device)

Content-Type: multipart/form-data
Body:
  file: <image_binary_data>
```

**Response (200 OK):**
```json
{
  "prediction": "pothole",
  "confidence": 0.92,
  "model_version": "1.0.0",
  "processing_time_ms": 245,
  "timestamp": 1647891234567
}
```

**Error Response (400/500):**
```json
{
  "error": "Invalid file type",
  "status": "error",
  "processing_time_ms": 15
}
```

#### GET /health

Health check endpoint.

**Request:**
```
GET http://10.0.2.2:5000/health
```

**Response (200 OK):**
```json
{
  "status": "healthy",
  "model_loaded": true,
  "model_name": "YOLOv5-Pothole",
  "model_version": "1.0.0",
  "api_version": "1.0",
  "timestamp": 1647891234567
}
```

### Dart API Reference

#### FlaskPotholeService

```dart
final service = FlaskPotholeService();

// Predict pothole
final result = await service.predictPothole(
  imageFile: File('path/to/image.jpg'),
);

print('Prediction: ${result.prediction}');
print('Confidence: ${result.confidencePercent}%');
print('Is Pothole: ${result.isPothole}');

// Test connection
final connected = await service.testConnection();
```

#### AiReportingIntegration

```dart
final integration = AiReportingIntegration(
  config: const AiIntegrationConfig(
    enabled: true,
    autoSelectPotholeCategory: true,
  ),
);

// Analyze image
final result = await integration.analyzeImage(
  imageFile: capturedImage,
  onAnalyzing: () => setState(() => loading = true),
);

// Build UI
if (result != null) {
  final widget = integration.buildResultWidget(result);
}
```

---

## 🔌 Integration Steps

### Step 1: Capture and Analyze Image

```dart
Future<void> _prepareCapturedImageWithAi(XFile photo) async {
  // Compress image (existing code)
  final File preparedImage = await _compressImage(File(photo.path));
  
  // Start AI analysis
  _aiState.startAnalyzing();
  setState(() {});
  
  try {
    // Call AI service
    final EnhancedAiResult? aiResult = await _aiIntegration.analyzeImage(
      imageFile: preparedImage,
    );
    
    if (aiResult != null) {
      // Store result
      _potholeResult = aiResult.detection;
      _aiState.completeAnalysis(aiResult.detection);
      
      // Auto-select category if high confidence pothole
      if (aiResult.detection.isPothole && 
          aiResult.detection.confidence >= 0.7) {
        setState(() => _selected = IssueCategory.values.firstWhere(
          (cat) => cat.name == 'Pothole',
          orElse: () => _selected!,
        ));
      }
    } else {
      _aiState.failAnalysis('Analysis failed');
    }
  } catch (e) {
    _aiState.failAnalysis(e.toString());
  }
  
  setState(() => _processingImage = false);
}
```

### Step 2: Display Result

```dart
// In build method, show result card
if (_aiState.isAnalyzing)
  _aiIntegration.buildLoadingWidget()
else if (_aiState.hasError)
  _aiIntegration.buildErrorWidget(
    message: _aiState.errorMessage,
    onRetry: () => _retryAiAnalysis(),
  )
else if (_potholeResult != null)
  _aiIntegration.buildResultWidget(
    EnhancedAiResult(
      detection: _potholeResult!,
      imagePath: _preparedImageFile?.path ?? '',
    ),
  ),
```

### Step 3: Submit with AI Data

```dart
Future<void> _submit() async {
  // ... existing validation ...
  
  // Use AI result if available
  final AiResult aiResult = _potholeResult != null
      ? AiResult(
          category: _potholeResult!.isPothole ? 'Pothole' : _selected!.name,
          severity: _potholeResult!.severity,
          confidence: _potholeResult!.confidence,
          boxes: const [],
        )
      : await _aiService.analyzeRoadImage(
          imageFile: imageFile,
          fallbackCategory: _selected!.name,
        );
  
  // Create report with AI metadata
  final reportId = await repository.createReport(
    category: aiResult.category,
    // ... other fields ...
    aiSeverity: aiResult.severity,
    aiConfidence: aiResult.confidence,
  );
}
```

---

## 🎨 UI Components

### AiPotholeResultCard

Beautiful animated card showing detection results.

**Features:**
- Smooth fade-in and scale animation
- Color coded: Red (pothole) / Green (normal)
- Confidence progress bar
- Icon indicators (⚠️/ ✅)
- Responsive design

**Usage:**
```dart
AiPotholeResultCard(
  result: result,
  onDismiss: () => setState(() => _potholeResult = null),
  animationDuration: Duration(milliseconds: 600),
)
```

### AiLoadingCard

Animated loading state during analysis.

**Features:**
- Pulsing opacity animation
- Progress indicator
- Localized text

**Usage:**
```dart
const AiLoadingCard()
```

### AiErrorCard

Error state with optional retry.

**Features:**
- Error icon and message
- Optional retry button
- Orange warning color

**Usage:**
```dart
AiErrorCard(
  message: 'Connection failed',
  onRetry: () => retryAnalysis(),
)
```

---

## 🧪 Testing

### 1. Test Flask Server

```bash
# Check if server is running
curl http://localhost:5000/health

# Expected response:
# {"status":"healthy","model_loaded":true,...}
```

### 2. Test with cURL

```bash
# Send test image
curl -X POST \
  -F "file=@test_image.jpg" \
  http://localhost:5000/predict

# Expected response:
# {"prediction":"pothole","confidence":0.92,...}
```

### 3. Test in Flutter

```dart
void _testAiIntegration() async {
  // 1. Test connection
  final connected = await _aiIntegration.testConnection();
  print('Connected: $connected');
  
  // 2. Test prediction
  final result = await _aiIntegration.analyzeImage(
    imageFile: File('test_image.jpg'),
  );
  print('Prediction: ${result?.detection.prediction}');
}
```

### 4. Mock Testing (Without Flask)

```dart
// Disable AI in config for testing without Flask
const aiConfig = AiIntegrationConfig(
  enabled: false,
  ALLOW_FALLBACK_ON_ERROR: true,
);
```

### 5. Test on Android Emulator

```bash
# Start emulator
emulator -avd Pixel_4_API_30

# Run Flutter app
flutter run -d emulator-5554

# Flask should be accessible at http://10.0.2.2:5000
```

### 6. Test on Physical Device

```bash
# 1. Find your machine's IP
ipconfig getifaddr en0  # macOS
hostname -I            # Linux
ipconfig               # Windows

# 2. Update AiServiceConfig.FLASK_DEVICE_URL with IP
# Example: 192.168.1.100:5000

# 3. Run app on device
flutter run -d <device_id>
```

---

## 🔧 Troubleshooting

### Issue: "AI unavailable, continue manually"

**Causes:**
- Flask server not running
- Wrong base URL
- Network connectivity issue
- Server timeout

**Solutions:**
```bash
# 1. Check Flask is running
ps aux | grep flask_app.py

# 2. Test connection
curl http://localhost:5000/health

# 3. Check firewall allows port 5000
lsof -i :5000

# 4. Restart Flask
python ai/flask_app.py
```

### Issue: Emulator Can't Reach Flask

**Causes:**
- Flask not listening on 0.0.0.0
- Port 5000 blocked
- Wrong IP (10.0.2.2)

**Solutions:**
```bash
# 1. Verify Flask listens on all interfaces
# In flask_app.py, ensure: app.run(host='0.0.0.0', port=5000)

# 2. Test from emulator
adb shell curl http://10.0.2.2:5000/health

# 3. Disable firewall temporarily
sudo ufw disable  # Linux
```

### Issue: Pothole Not Auto-Selected

**Causes:**
- Confidence below threshold (< 0.7)
- `autoSelectPotholeCategory` is false
- Category not found

**Solutions:**
```dart
// 1. Lower confidence threshold
const AiIntegrationConfig(
  // ... existing config ...
  // AUTO_ACCEPT_CONFIDENCE_THRESHOLD set in ai_config.dart
)

// 2. Enable auto-selection
const AiIntegrationConfig(
  autoSelectPotholeCategory: true,
)

// 3. Check category exists
print(IssueCategory.values.map((c) => c.name))
```

### Issue: Image Upload Fails

**Causes:**
- Image too large (> 16MB)
- Unsupported format
- Memory issues

**Solutions:**
```dart
// Process image before sending
final File compressed = await _compressImage(originalImage);

// Verify file exists
assert(compressed.existsSync());

// Check file size
final sizeBytes = await compressed.length();
final sizeMB = sizeBytes / (1024 * 1024);
print('Image size: ${sizeMB.toStringAsFixed(2)}MB');
```

### Issue: UI Freezes During Analysis

**Causes:**
- Long timeout (default 30 seconds)
- Heavy UI rendering
- Network latency

**Solutions:**
```dart
// 1. Reduce timeout
const AiIntegrationConfig(
  timeoutSeconds: 15,  // Shorter timeout
)

// 2. Use async/await properly
// Ensure all async operations use .timeout()

// 3. Monitor performance
flutter run --profile
```

---

## ⚙️ Advanced Configuration

### Production Preset

```dart
final config = AiIntegrationConfig(
  enabled: true,
  autoSelectPotholeCategory: false,  // More conservative
  autoSetHighPriority: false,
  timeoutSeconds: 15,
  // ... rest of config ...
);
```

### Hackathon Demo Preset

```dart
final config = AiIntegrationConfig(
  enabled: true,
  autoSelectPotholeCategory: true,   // Aggressive AI
  autoSetHighPriority: true,
  showResultCard: true,
  timeoutSeconds: 10,
);
```

### Custom Model Integration

Replace mock model in `flask_app.py`:

```python
from ultralytics import YOLO

class PotholeDetectionModel:
    def __init__(self):
        self.model = YOLO('path/to/best.pt')
        self.version = "1.0.0"
    
    def predict(self, image_path):
        results = self.model.predict(image_path, conf=0.5)
        # Process results...
```

### Analytics Integration

```dart
_analytics.logAiPrediction(
  prediction: result.detection.prediction,
  confidence: result.detection.confidence,
  category: _selected?.name ?? 'unknown',
  userAccepted: true,
);
```

---

## 📊 Performance Metrics

### Expected Performance

- **Image compression**: ~200ms
- **Network upload**: ~500ms-2s (varies by network)
- **Flask inference**: ~100-500ms (depends on model)
- **Total E2E**: ~1-3 seconds

### Optimization Tips

1. Compress images to < 200KB
2. Use WiFi instead of cellular
3. Keep Flask server warm (avoid cold starts)
4. Monitor with Flutter DevTools profiler

```bash
flutter run --profile
```

---

## 🤝 Support & Contributing

### Integration Checklist

- [ ] Flask dependencies installed
- [ ] Flask server running on port 5000
- [ ] Flutter imports updated
- [ ] State fields added to ReportWizardScreen
- [ ] _prepareCapturedImage updated with AI logic
- [ ] UI components integrated in build()
- [ ] _submit() uses AI results
- [ ] Testing on emulator/device
- [ ] Error handling verified
- [ ] Analytics logging added

### Files to Review

1. [lib/services/flask_pothole_service.dart](lib/services/flask_pothole_service.dart) - Core service
2. [lib/ui_theme/ai_result_card.dart](lib/ui_theme/ai_result_card.dart) - UI components
3. [lib/reporting/ai_reporting_integration.dart](lib/reporting/ai_reporting_integration.dart) - Integration
4. [lib/services/ai_config.dart](lib/services/ai_config.dart) - Configuration
5. [ai/flask_app.py](ai/flask_app.py) - Backend server

---

## 📝 Notes

- All existing features (Firebase, Supabase, maps) are preserved
- AI is optional - app works without Flask
- Graceful degradation on network errors
- Suitable for hackathon demos and production

---

**Created**: March 2026
**Version**: 1.0.0
**Status**: Ready for Integration
