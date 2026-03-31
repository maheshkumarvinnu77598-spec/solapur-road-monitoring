# 🚀 AI Pothole Integration - Quick Reference

**One-page reference for developers integrating Flask AI into Solapur Road Monitoring.**

---

## 📋 Files Created

```
✅ lib/services/flask_pothole_service.dart          - Flask API client
✅ lib/ui_theme/ai_result_card.dart                 - Result display widgets  
✅ lib/reporting/ai_reporting_integration.dart      - Integration manager
✅ lib/services/ai_config.dart                      - Configuration
✅ ai/flask_app.py                                  - Flask backend server
✅ AI_POTHOLE_INTEGRATION.md                        - Main documentation
✅ AI_INTEGRATION_CHECKLIST.md                      - Step-by-step checklist
✅ IMPLEMENTATION_SUMMARY.md                        - This overview
```

---

## ⚡ 5-Minute Setup

### Backend (Flask)
```bash
cd solapur_road_monitoring
pip install flask flask-cors pillow werkzeug
python ai/flask_app.py
# Should see: "📡 Starting server on http://localhost:5000"
```

### Frontend (Flutter)
```bash
# Add to report_wizard_screen.dart
import '../services/flask_pothole_service.dart';
import '../reporting/ai_reporting_integration.dart';
import '../ui_theme/ai_result_card.dart';

// In initState():
_aiIntegration = AiReportingIntegration(
  config: const AiIntegrationConfig(enabled: true),
);
_aiIntegration.initialize();

# Then follow EXAMPLE_AI_INTEGRATION.dart
```

---

## 🎯 Key APIs

### FlaskPotholeService
```dart
final service = FlaskPotholeService();

// Predict pothole
final result = await service.predictPothole(imageFile: image);
// Returns: PotholeDetectionResult
//   - prediction: "pothole" | "normal"
//   - confidence: 0.0-1.0
//   - isPothole: bool
//   - confidencePercent: int (0-100)

// Test connection
final ok = await service.testConnection();
```

### AiReportingIntegration
```dart
final integration = AiReportingIntegration(
  config: const AiIntegrationConfig(
    enabled: true,
    autoSelectPotholeCategory: true,
    autoSetHighPriority: true,
    showResultCard: true,
    timeoutSeconds: 30,
  ),
);

// Analyze image
final result = await integration.analyzeImage(
  imageFile: image,
);

// Build UI widgets
final widget = integration.buildResultWidget(result);
final loading = integration.buildLoadingWidget();
final error = integration.buildErrorWidget(message: "...");
```

### UI Components
```dart
// Show result card
AiPotholeResultCard(result: detection)

// Show loading
AiLoadingCard()

// Show error
AiErrorCard(message: "...", onRetry: () {})
```

---

## 🔌 Integration Points

### Step 1: Add Fields
```dart
late final AiReportingIntegration _aiIntegration;
final AiAnalysisState _aiState = AiAnalysisState();
PotholeDetectionResult? _potholeResult;
```

### Step 2: Initialize
```dart
@override
void initState() {
  super.initState();
  _aiIntegration = AiReportingIntegration(
    config: const AiIntegrationConfig(enabled: true),
  );
  _aiIntegration.initialize();
}
```

### Step 3: Analyze Images
```dart
// In _prepareCapturedImage() after compression & fraud check:
_aiState.startAnalyzing();
setState(() {});

final EnhancedAiResult? result = 
    await _aiIntegration.analyzeImage(imageFile: preparedImage);

if (result != null) {
  _potholeResult = result.detection;
  _aiState.completeAnalysis(result.detection);
  
  // Auto-select if high confidence pothole
  if (result.detection.isPothole && 
      result.detection.confidence >= 0.7) {
    setState(() => _selected = potholeCat);
  }
} else {
  _aiState.failAnalysis("Analysis failed");
}
```

### Step 4: Display Results
```dart
// In build() method, in image capture step:
if (_aiState.isAnalyzing)
  _aiIntegration.buildLoadingWidget()
else if (_aiState.hasError)
  _aiIntegration.buildErrorWidget(onRetry: _retryAiAnalysis)
else if (_potholeResult != null)
  _aiIntegration.buildResultWidget(/*...*/),
```

### Step 5: Submit with AI
```dart
// In _submit():
final AiResult aiResult = _potholeResult != null
    ? AiResult(
        category: _potholeResult!.isPothole ? 'Pothole' : selected.name,
        severity: _potholeResult!.severity,
        confidence: _potholeResult!.confidence,
        boxes: const [],
      )
    : await _aiService.analyzeRoadImage(
        imageFile: imageFile,
        fallbackCategory: selected.name,
      );

// Use aiResult.category, severity, confidence in report
```

---

## 🔗 API Endpoints

### Flask Endpoints

```
POST /predict
├── Request: multipart/form-data with "file" field
├── Response (200):
│   {
│     "prediction": "pothole|normal",
│     "confidence": 0.0-1.0,
│     "model_version": "1.0.0",
│     "processing_time_ms": 250
│   }
└── Error (4xx/5xx): {"error": "...", "status": "error"}

GET /health
├── Response: {"status": "healthy", "model_loaded": true, ...}
└── Use to test connection

GET /
└── Response: API info and endpoints
```

### URLs
- **Emulator**: `http://10.0.2.2:5000/predict`
- **Local Device**: `http://localhost:5000/predict`
- **Physical Device**: `http://<your-ip>:5000/predict`

---

## ⚙️ Configuration Presets

### Development
```dart
const AiIntegrationConfig(
  enabled: true,
  autoSelectPotholeCategory: true,
  autoSetHighPriority: true,
  showResultCard: true,
  timeoutSeconds: 30,
)
```

### Production
```dart
const AiIntegrationConfig(
  enabled: true,
  autoSelectPotholeCategory: false,  // More conservative
  autoSetHighPriority: false,
  showResultCard: true,
  timeoutSeconds: 15,
)
```

### Hackathon Demo
```dart
const AiIntegrationConfig(
  enabled: true,
  autoSelectPotholeCategory: true,   // Aggressive
  autoSetHighPriority: true,
  showResultCard: true,
  timeoutSeconds: 10,
)
```

---

## 🧪 Testing

### Test Flask
```bash
# Health check
curl http://localhost:5000/health

# Test prediction
curl -X POST -F "file=@test.jpg" http://localhost:5000/predict

# From emulator
adb shell curl http://10.0.2.2:5000/health
```

### Test Flutter
```bash
# Emulator
flutter run -d emulator-5554

# Physical device (ensure same WiFi)
flutter run -d <device-id>

# Check Flask logs for incoming requests
```

### Test Workflow
1. Launch app
2. Select "Pothole" category
3. Capture image
4. Watch for "Analyzing image..." card
5. See result card (red pothole / green normal)
6. Verify auto-selection if pothole
7. Continue with GPS and submit

---

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| "AI unavailable" | Check Flask running: `python ai/flask_app.py` |
| Timeout error | Reduce `timeoutSeconds` in config, check Flask speed |
| Pothole not auto-selected | Check confidence >= 0.7, verify `autoSelectPotholeCategory` is true |
| UI freezes | Image too large, reduce quality or dimensions |
| Memory spike | Use image compression, check file sizes |
| Can't reach emulator | Ensure Flask uses `host='0.0.0.0'` |
| Physical device can't connect | Use machine IP (not localhost), ensure same WiFi |

---

## 📊 Performance

- Image compression: ~200ms
- Network upload: ~500ms-2s
- Flask inference: ~100-500ms
- **Total**: ~1-3 seconds
- Target image size: < 200KB

---

## 🎯 Success Checklist

- [ ] Flask server running on port 5000
- [ ] Imports added to report_wizard_screen.dart
- [ ] AI fields initialized in initState()
- [ ] Image analysis integrated in _prepareCapturedImage()
- [ ] Result card displayed in build()
- [ ] Auto-selection working for high-confidence predictions
- [ ] Error handling shows user-friendly messages
- [ ] Reports save with AI metadata
- [ ] Works on emulator and physical device
- [ ] No UI freezing or memory leaks

---

## 💡 Pro Tips

1. **Image Optimization** - Compress to < 200KB for fast inference
2. **Timeout Tuning** - Reduce for fast networks, increase for slow
3. **Confidence Threshold** - 0.7+ for auto-select, higher for production
4. **Error Recovery** - Always provide retry button and fallback
5. **Testing** - Test without Flask first (disable AI in config)
6. **Logging** - Enable DEBUG_LOGGING in ai_config.dart for debugging
7. **Model Loading** - Load Flask model once on startup, not per request
8. **Caching** - Store recent predictions to avoid redundant requests
9. **Analytics** - Log predictions to track accuracy and patterns
10. **Gradual Rollout** - Enable for 10% users first, monitor

---

## 🚀 Quick Commands

```bash
# Run Flask
python ai/flask_app.py

# Run Flutter
flutter run

# Format code
flutter format lib/

# Analyze
flutter analyze

# Test
flutter test

# Build APK
flutter build apk --release

# Clean build
flutter clean && flutter pub get
```

---

## 📚 More Info

| Document | Content |
|----------|---------|
| AI_POTHOLE_INTEGRATION.md | Complete guide (500+ lines) |
| AI_INTEGRATION_CHECKLIST.md | Step-by-step checklist (22 phases) |
| EXAMPLE_AI_INTEGRATION.dart | Full code example |
| AI_INTEGRATION_GUIDE.dart | Reference with comments |
| flask_pothole_service.dart | Service implementation |
| ai_result_card.dart | UI components |
| ai_reporting_integration.dart | Integration manager |
| ai_config.dart | Configuration options |
| flask_app.py | Backend server |

---

## 🎉 You're Ready!

**Start here**: AI_INTEGRATION_CHECKLIST.md

Phase by phase, you'll integrate AI pothole detection into your app.

Questions? Check AI_POTHOLE_INTEGRATION.md → Troubleshooting section.

Good luck! 🚀

---

*Created March 19, 2026 | Version 1.0.0*
