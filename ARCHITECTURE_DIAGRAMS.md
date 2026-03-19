# 🏗️ AI Pothole Detection - System Architecture

Visual overview of the complete AI integration system.

---

## 🎬 High-Level Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     FLUTTER APP                                 │
│                  (Solapur Road Monitoring)                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │         User Interface (Report Wizard Screen)            │   │
│  ├──────────────────────────────────────────────────────────┤   │
│  │  Step 1: Select Category  (existing code)                │   │
│  │  Step 2: Capture Image    (enhanced with AI)      ◄─────┼───┤
│  │  Step 3: Detect GPS       (existing code)         │     │   │
│  │  Step 4: Add Description  (existing code)         │     │   │
│  │  Step 5: Submit Report    (enhanced with AI)      │     │   │
│  └──────────────────────────────────────────────────────────┘   │
│                           │                                       │
│                           ▼                                       │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │          Image Processing (NEW)                          │   │
│  ├──────────────────────────────────────────────────────────┤   │
│  │                                                            │   │
│  │  1. Image Capture/Selection (ImagePicker)                │   │
│  │         ↓                                                  │   │
│  │  2. Image Compression (flutter_image_compress)           │   │
│  │         ↓                                                  │   │
│  │  3. Fraud Detection (existing FraudDetectionService)     │   │
│  │         ↓                                                  │   │
│  │  4. Flask AI Analysis (NEW) ◄──────┐                     │   │
│  │         ↓                           │                     │   │
│  │  5. Display Result Card (NEW)       │                     │   │
│  │         ↓                           │                     │   │
│  │  6. Auto-Selection (NEW)            │                     │   │
│  │         ↓                           │                     │   │
│  │  7. Report Submission                │                     │   │
│  │         ↓                           │                     │   │
│  │  8. Firebase Upload (existing)       │                     │   │
│  │     with AI Metadata (NEW)           │                     │   │
│  │                                      │                     │   │
│  └──────────────────────────────────────┤─────────────────────┘   │
│                                         │                         │
└─────────────────────────────────────────┼─────────────────────────┘
                                          │
                                    NETWORK (HTTP/REST)
                                          │
┌─────────────────────────────────────────▼─────────────────────────┐
│                     FLASK BACKEND                 ◄───────────────┤
│              (New AI/flask_app.py)                                 │
├──────────────────────────────────────────────────────────────────┤
│                                                                    │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │  POST /predict                                           │    │
│  │  ┌────────────────────────────────────────────────────┐ │    │
│  │  │ 1. Receive image (multipart/form-data)             │ │    │
│  │  │ 2. Validate file (type, size)                      │ │    │
│  │  │ 3. Preprocess image (resize, normalize)            │ │    │
│  │  │ 4. Run ML model (YOLOv5/YOLOv8)                   │ │    │
│  │  │ 5. Get predictions & confidence                    │ │    │
│  │  │ 6. Return JSON response                            │ │    │
│  │  └────────────────────────────────────────────────────┘ │    │
│  └──────────────────────────────────────────────────────────┘    │
│                         │                                         │
│                         ▼                                         │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │  GET /health                                             │    │
│  │  (Status check endpoint)                                 │    │
│  └──────────────────────────────────────────────────────────┘    │
│                                                                    │
└──────────────────────────────────────────────────────────────────┘
```

---

## 🔗 Component Interactions

```
╔═══════════════════════════════════════════════════════════════════╗
║                  AiReportingIntegration                           ║
║              (High-level coordinator)                             ║
╠═══════════════════════════════════════════════════════════════════╣
║                                                                    ║
║  Uses Configuration:                                              ║
║  ┌─────────────────────────────────────────────────────────────┐ ║
║  │ • enabled: bool (enable/disable AI)                        │ ║
║  │ • autoSelectPotholeCategory: bool (auto-select category)   │ ║
║  │ • autoSetHighPriority: bool (auto-set priority)            │ ║
║  │ • showResultCard: bool (show UI)                           │ ║
║  │ • timeoutSeconds: int (request timeout)                    │ ║
║  │ • flaskBaseUrl: String? (custom Flask URL)                 │ ║
║  └─────────────────────────────────────────────────────────────┘ ║
║                                                                    ║
║  Methods:                                                          ║
║  ┌─────────────────────────────────────────────────────────────┐ ║
║  │ • analyzeImage(imageFile) → EnhancedAiResult?              │ ║
║  │ • buildResultWidget(result) → Widget                       │ ║
║  │ • buildLoadingWidget() → Widget                            │ ║
║  │ • buildErrorWidget(message) → Widget                       │ ║
║  │ • testConnection() → bool                                  │ ║
║  └─────────────────────────────────────────────────────────────┘ ║
║                       │                                            ║
║                       ▼                                            ║
║  ┌─────────────────────────────────────────────────────────────┐ ║
║  │        FlaskPotholeService                                 │ ║
║  │     (HTTP communication)                                   │ ║
║  │                                                             │ ║
║  │  • predictPothole(imageFile) → PotholeDetectionResult     │ ║
║  │  • testConnection() → bool                                 │ ║
║  │  • Device detection (emulator vs device)                   │ ║
║  │  • Error handling & timeouts                               │ ║
║  └─────────────────────────────────────────────────────────────┘ ║
║                       │                                            ║
║                       ▼                                            ║
║  ┌─────────────────────────────────────────────────────────────┐ ║
║  │  State Management                                           │ ║
║  │  (AiAnalysisState)                                          │ ║
║  │                                                             │ ║
║  │  States:                                                    │ ║
║  │    • isAnalyzing → show loading card                       │ ║
║  │    • hasError → show error card                            │ ║
║  │    • result != null → show success card                    │ ║
║  └─────────────────────────────────────────────────────────────┘ ║
║                       │                                            ║
║                       ▼                                            ║
║  ┌─────────────────────────────────────────────────────────────┐ ║
║  │        UI Components                                        │ ║
║  │     (ai_result_card.dart)                                   │ ║
║  │                                                             │ ║
║  │  • AiPotholeResultCard (animated result display)            │ ║
║  │  • AiLoadingCard (pulsing load indicator)                  │ ║
║  │  • AiErrorCard (error with retry)                          │ ║
║  └─────────────────────────────────────────────────────────────┘ ║
║                                                                    ║
╚═══════════════════════════════════════════════════════════════════╝
```

---

## 📊 Data Flow

```
IMAGE CAPTURE
    │
    ▼
┌─────────────────────┐
│  ImagePicker        │  Select or capture image
│  (existing)         │  Returns XFile
└────────────────────┬┘
                    │
                    ▼
              ┌──────────────────────┐
              │ Image Compression    │
              │ (float_image_compress)
              │ Target: < 200KB      │
              └─────────┬────────────┘
                        │
                        ▼
              ┌──────────────────────┐
              │ Fraud Detection      │
              │ (existing service)   │
              │ Validate image       │
              └─────────┬────────────┘
                        │
                    YES │
                        │
                        ▼
        ┌───────────────────────────────┐
        │   Flask AI Analysis (NEW)     │
        │                               │
        │  1. Create multipart request  │
        │  2. Send to /predict endpoint │
        │  3. Parse JSON response       │
        │  4. Handle timeouts/errors    │
        │                               │
        │  Response:                    │
        │  {                            │
        │    "prediction": "pothole",   │
        │    "confidence": 0.92,        │
        │    "processing_time_ms": 250  │
        │  }                            │
        └────────┬──────────────────────┘
                 │
         ┌───────┴─────────┐
         │                 │
         ▼ (success)       ▼ (error)
    ┌─────────────┐   ┌──────────────┐
    │ Result Card │   │ Error Card   │
    │ (show red/  │   │ (with retry  │
    │  green)     │   │  button)     │
    └──────┬──────┘   └──────┬───────┘
           │                 │
           └────────┬────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │ Auto-Selection (NEW)  │
        │                       │
        │ If pothole && conf>0.7│
        │   → Select "Pothole"  │
        │   → Set priority High │
        └───────┬───────────────┘
                │
                ▼
        ┌───────────────────────┐
        │ Report Submission     │
        │                       │
        │ Send to Firebase with:│
        │ • ai_prediction       │
        │ • ai_confidence       │
        │ • ai_severity         │
        │ • ai_boxes (det.)     │
        └───────┬───────────────┘
                │
                ▼
        ┌───────────────────────┐
        │ Report Saved ✅       │
        │                       │
        │ With AI metadata      │
        │ for analytics         │
        └───────────────────────┘
```

---

## 🎨 UI Component Tree

```
ReportWizardScreen
│
├── Step: "Select Category"
│   └── CategoryDropdown
│       └── [Pothole, Road Damage, Pothole, Manhole, Speed Breaker]
│
├── Step: "Capture Image"  ◄─── AI integration here
│   ├── ImagePreview (if image selected)
│   │
│   ├─── NEW: AI Result Cards
│   │   ├── Loading State
│   │   │   └── AiLoadingCard
│   │   │       ├── CircularProgressIndicator
│   │   │       └── Text: "Analyzing image…"
│   │   │
│   │   ├── Success State
│   │   │   └── AiPotholeResultCard
│   │   │       ├── Header (Icon + Title)
│   │   │       ├── Confidence Section
│   │   │       │   ├── "Confidence: 92%"
│   │   │       │   └── LinearProgressIndicator
│   │   │       └── Info Box
│   │   │           └── "Pothole detected. Auto-set to High priority"
│   │   │
│   │   └── Error State
│   │       └── AiErrorCard
│   │           ├── Icon (info_outline)
│   │           ├── Text: "AI analysis failed…"
│   │           └── OutlinedButton: "Retry Analysis"
│   │
│   └── Button: "Capture Image"
│
├── Step: "Detect GPS"
│   ├── Text: Location coordinates
│   └── Button: "Detect GPS"
│
└── Step: "Description"
    ├── TextField: Description
    └── Button: "Submit"
```

---

## ⚡ Performance Timeline

```
TIME (milliseconds)
│
0ms  ├─ User taps "Capture Image"
     │
50ms ├─ ImagePicker opens
     │
500ms├─ Image captured/selected
     │
600ms├─ Image loading from file
     │
800ms├─ Image compression starts
     │
1000ms├─ Compression complete (~100-200KB)
     │
1100ms├─ Fraud detection starts
     │
1200ms├─ Fraud check complete
     │
1250ms├─ Show loading card "Analyzing image…"
     │
1300ms├─ Compress for upload
     │
1500ms├─ HTTP request sent to Flask
     │
3000ms├─ Flask processing complete (~1000ms)
     │
3200ms├─ Response received + parsed
     │
3300ms├─ Result card animation starts (600ms)
     │
3900ms├─ Animation complete, result card displayed ✅
     │
     └─── TOTAL: ~4 seconds (can be 2-3s on fast networks)
```

---

## 🔄 State Machine

```
Initial State: IDLE

    ↓

User captures image
    │
    ▼
[IMAGE_CAPTURED]
    └─ Load image file
    └─ Compress image
    └─ Check fraud detection
    └─ Reset AI state
    │
    ▼
[AI_ANALYZING]
    ├─ Show: AiLoadingCard
    ├─ Send request to Flask
    ├─ Wait for response
    │
    ├─ Success branch:
    │   ▼
    │  [AI_SUCCESS]
    │   ├─ Parse prediction
    │   ├─ Show: AiPotholeResultCard
    │   ├─ Auto-select category if pothole
    │   ├─ Set priority if needed
    │   └─ Ready for submission
    │
    └─ Failure branch:
        ▼
       [AI_ERROR]
        ├─ Show: AiErrorCard
        ├─ Show retry button
        ├─ Allow manual category selection
        └─ Ready for submission (without AI)

Any state:
    └─ User taps "Capture Image" again
        └─ Reset state → [IMAGE_CAPTURED]
```

---

## 📱 Device-Specific URLs

```
┌────────────────────────────────────────────────────────────┐
│                  Flask Server                              │
│                http://localhost:5000                       │
└────────────────────────────────────────────────────────────┘
          └─────────────┬──────────────┘
                        │
        ┌───────────────┼───────────────┐
        │               │               │
        ▼               ▼               ▼

    Android        iOS              Web
    Emulator       Simulator        Browser
        │               │               │
        ▼               ▼               ▼

http://10.0.2.2:5000        http://localhost:5000  (auto-detects)
(Fixed: special emulator IP)  (Same machine)

        │                               ▼
        │                           
        │               Physical Device
        │               (any platform)
        │                       │
        │                       ▼
        │               Must replace localhost
        │               with machine IP:
        │               
        │               192.168.1.100:5000
        │               172.20.10.0:5000
        │               (same WiFi required)
        │
        └─── Configured in:
             FlaskPotholeService._isEmulator() 
             or AiIntegrationConfig.flaskBaseUrl
```

---

## 🔐 Error Handling Tree

```
analyzeImage()
    │
    ├─ Image validation
    │   ├─ NOT_EXISTS → return null
    │   ├─ NOT_READABLE → return null
    │   └─ TOO_LARGE → return null
    │
    ├─ Network request
    │   ├─ TIMEOUT (30s default)
    │   │   ├─ Show: error card "timeout"
    │   │   └─ User can retry
    │   │
    │   ├─ NO_NETWORK
    │   │   ├─ Show: error card "offline"
    │   │   └─ Continue manually
    │   │
    │   ├─ SERVER_ERROR (5xx)
    │   │   ├─ Show: error card "server error"
    │   │   └─ Suggest retry
    │   │
    │   └─ CLIENT_ERROR (4xx)
    │       ├─ Show: error card "invalid file"
    │       └─ User should recapture
    │
    ├─ Response parsing
    │   ├─ INVALID_JSON → return null
    │   ├─ MISSING_FIELD → return null
    │   └─ INVALID_CONFIDENCE → clamp to 0.0-1.0
    │
    └─ Unknown error
        ├─ Log for debugging
        └─ Show generic error card
```

---

## 💾 Data Structures

```
PotholeDetectionResult
├─ prediction: "pothole" | "normal"
├─ confidence: 0.0 - 1.0
├─ isPothole: bool (computed)
├─ confidencePercent: int (0-100)
├─ predictionText: String ("Pothole Detected" | "Normal Road")
├─ severity: "low" | "medium" | "high"
└─ rawResponse: String?

EnhancedAiResult
├─ detection: PotholeDetectionResult
├─ analyzedAt: DateTime
├─ imagePath: String
├─ isRetry: bool
├─ suggestedCategory: String
├─ suggestedPriority: String
└─ shouldAutoApply: bool

AiAnalysisState
├─ result: PotholeDetectionResult?
├─ isAnalyzing: bool
├─ hasError: bool
├─ errorMessage: String?
└─ analyzedAt: DateTime?
```

---

**Diagrams created March 19, 2026**

