# 18 — AI IDE Master Prompts
## ECHO AAC | Copy-Paste Prompts for Every Feature

---

> This file is your **cheat sheet**. Every feature in ECHO, distilled into a clear, copy-paste-ready prompt. Use these in Antigravity IDE, Cursor, Windsurf, or any AI IDE.

---

## How to Use This File

1. Open your AI IDE
2. Find the feature you're building (in order)
3. Copy the prompt block
4. Paste into your AI IDE chat
5. Review the output against the detailed spec in the corresponding numbered file
6. Fix any discrepancies
7. Move to next prompt

---

## 🚀 PHASE 1: Foundation

### PROMPT 1 — Project Setup
```
Create a Flutter project called echo_aac for a medical AAC app (eye-gaze 
communication for paralyzed patients). 

Set up:
1. pubspec.yaml with these dependencies:
   flutter_riverpod, hooks_riverpod, go_router, google_mlkit_face_detection, 
   camera, flutter_tts, record, just_audio, telephony, geolocator, 
   permission_handler, local_auth, flutter_secure_storage, flutter_animate, 
   fl_chart, vibration, flutter_dotenv, supabase_flutter, hive_flutter, 
   hive, connectivity_plus, device_info_plus, rxdart, freezed_annotation, 
   json_annotation, uuid, intl, flutter_blue_plus, audioplayers, logger,
   shimmer, google_fonts

2. main.dart that initializes: dotenv, Hive (registers all adapters), 
   Supabase, locks screen to portrait, sets immersive mode, then runs app 
   wrapped in ProviderScope

3. AndroidManifest.xml with permissions: CAMERA, RECORD_AUDIO, SEND_SMS, 
   ACCESS_FINE_LOCATION, INTERNET, VIBRATE, WAKE_LOCK

4. iOS Info.plist with camera, microphone, and location usage descriptions

5. Complete folder structure:
   lib/core/, lib/features/, lib/data/, lib/shared/
   Each feature folder: gaze_engine, keyboard, prediction, voice, 
   emergency, calibration, phrases, caregiver, communication, onboarding

6. app.dart with GoRouter navigation and MaterialApp dark theme (#0D1117 bg)

7. .env template file (placeholder keys, never real values)
```

---

### PROMPT 2 — Camera + MediaPipe Pipeline
```
Build the complete camera and MediaPipe face detection pipeline for ECHO.

CameraService:
- Opens front camera at ResolutionPreset.high
- ImageFormatGroup.yuv420 format
- Streams CameraImage frames at 60fps
- Prevents frame queue buildup: skip frame if previous still processing
- Lifecycle methods: initialize(), pause(), resume(), dispose()

MediaPipeService:
- Uses google_mlkit_face_detection with: enableLandmarks, enableClassification, 
  enableContours all set to true, performanceMode: FaceDetectorMode.fast
- Converts CameraImage to InputImage (YUV420 → ML Kit format)
- Extracts eye corner landmarks from FaceContour
- Emits Stream<FaceLandmarksData?> — null when no face detected

FaceLandmarksData model:
- Both iris center positions (computed from eye contour center)
- 4 eye corner/lid points per eye (outer, inner, top, bottom)
- rightEyeOpenProbability, leftEyeOpenProbability from ML Kit
- headEulerX, headEulerY, headEulerZ
- Computed EAR (Eye Aspect Ratio) getter

BlinkDetector:
- Monitors EAR on every frame
- EAR < 0.20 = eye closed
- Single blink: 80-600ms duration
- Double blink: 2 single blinks within 800ms window
- Long blink: duration > 600ms
- Emits Stream<BlinkEvent> with type and duration

EchoCameraPreview widget: shows front camera thumbnail (80x80px) 
mirrored horizontally with green tracking dot overlay.
```

---

### PROMPT 3 — Gaze Vector Engine
```
Build the gaze calculation and dwell selection system for ECHO.

GazeCalculator:
- Takes FaceLandmarksData + screen Size
- Normalizes iris position within eye bounds: 
  normX = (iris.x - outerCorner.x) / eyeWidth
  normY = (iris.y - topLid.y) / eyeHeight
- Averages left and right eye (improves accuracy ~15%)
- Compensates head rotation: rawX += headEulerY * 0.015
- Applies exponential smoothing: smoothed = smoothed*0.65 + raw*0.35
- Applies CalibrationData offsets when available
- Returns GazePoint with x, y (pixels), normalizedX/Y, confidence, timestamp
- Confidence reduces based on head angle and eye openness

GazeZoneMapper:
- Stores Map<String, Rect> of zone ID → screen bounds
- getZoneAt(GazePoint) returns zone ID or null
- Falls back to nearest zone center when gaze is between zones
- Returns null if no zone within 80px

DwellTimerService:
- Tracks accumulated dwell time per zone
- Resets on zone change
- Emits Stream<String> selection event when dwell reaches threshold (default 600ms)
- Emits Stream<DwellProgress> (0.0-1.0) for visual feedback
- Grace period: 800ms before next selection possible

GazeCursorWidget:
- Positioned widget at gaze location
- Base size 24px → grows to 56px as dwell increases
- Color: blue (#58A6FF) → green (#3FB950) based on dwell progress  
- Glow effect at full dwell
- Uses AnimatedContainer for smooth transitions
- IgnorePointer: true (never blocks touches)

GazeEngineController (Riverpod StateNotifier):
- Orchestrates Camera → MediaPipe → Gaze → Zone → Dwell pipeline
- Exposes: selectionStream, progressStream, blinkStream
- registerKeyZone(id, rect) for keyboard/UI to register their bounds
- clearKeyZones() for layout changes
- State: currentGaze, isFaceDetected, trackingConfidence, isInitialized
```

---

### PROMPT 4 — 15-Point Calibration
```
Build the complete calibration system for ECHO eye tracking.

CalibrationData model (Freezed):
- scaleX, scaleY: how much to scale the gaze vector
- offsetX, offsetY: translation offset
- centerX, centerY: center of measured distribution
- points: List<CalibrationPoint> (15 target-measurement pairs)
- accuracyScore: 0.0-1.0
- userId, deviceId, createdAt

CalibrationService:
- 15 target positions in 5x3 grid at normalized coordinates:
  x: 0.10, 0.275, 0.45, 0.625, 0.80
  y: 0.10, 0.50, 0.90
- Collects 30 high-confidence (>0.6) gaze samples per target
- After collection: computes scaleX/Y and offsetX/Y via variance ratio method
- Calculates accuracy as (1.0 - avgError*5).clamp(0.0, 1.0)
- Emits Stream<CalibrationProgress> with currentTarget, pointIndex, progress

CalibrationActiveScreen:
- Dark background (#0D1117)
- Animated pulsing target dot: blue (#58A6FF), 60px, pulses via AnimatedBuilder
- AnimatedPositioned moves dot smoothly between targets
- Overall LinearProgressIndicator (blue on dark)
- Instructions: "Look at each dot. Keep your head still."

CalibrationResultScreen:
- Large accuracy percentage (72pt font)
- Green ≥90%, Amber 75-89%, Red <75%
- "Excellent calibration!" / "Acceptable" / "Try Again" text
- "Start Communicating" button if accuracy ≥75%
- "Recalibrate" always available

Save CalibrationData to Hive, keyed by userId+deviceId.
Load on app start and apply to GazeCalculator automatically.
```

---

## 🎹 PHASE 2: Keyboard + Intelligence

### PROMPT 5 — Gaze Keyboard
```
Build the complete eye-gaze keyboard for ECHO.

KeyboardKey model:
- id (unique for zone registration), display (shown), value (inserted), 
  type (letter/space/backspace/speak/phrases/clear), relativeWidth
- Space: relativeWidth=5.0, Speak: relativeWidth=2.5 green, Clear: red

KeyboardLayout.standard: 6 rows
- Row 1: Q W E R T Y U
- Row 2: I O P A S D F  
- Row 3: G H J K L Z X
- Row 4: C V B N M ⌫
- Row 5: [SPACE]
- Row 6: [SPEAK] [PHRASES] [CLEAR]

GazeKeyWidget:
- Minimum height: 70px
- Default: dark card (#161B22) with white letter
- Dwell fill: fills from bottom in blue (#58A6FF) opacity 0.15
- Border interpolates from #30363D to #58A6FF during dwell
- Selected: green flash (#3FB950) + border glow
- Registers its screen bounds via GlobalKey after first layout

GazeKeyboard widget:
- LayoutBuilder → 7 column grid
- Listens to GazeEngine progressStream → updates dwellProgresses map
- Listens to GazeEngine selectionStream → calls _onKeySelected
- On selection: haptic feedback (letter=30ms/80amp, space=50ms/100amp, 
  speak=100ms/200amp), flash green state, call KeyboardController
- Registers ALL key bounds with GazeEngine after first build

MessageBarWidget:
- Shows typed message in 20pt white text
- Placeholder: "Start looking at letters to type..." (30% opacity)
- Purple pulsing dot (#BC8CFF) when speaking
- Word count bottom right
- Container: #161B22 bg, rounded corners, #30363D border

KeyboardController (Riverpod):
- handleKeyPress(key): letter adds to message, space adds " ", 
  backspace removes last char, SPEAK calls voice + saves + clears, CLEAR empties
- insertPrediction(text): replaces message with full prediction
- Auto-capitalize first letter of each new message
- On any text change: calls predictionController.onTextChanged()
```

---

### PROMPT 6 — Claude AI Predictions
```
Build the Claude AI prediction system for ECHO AAC.

ClaudePredictionService:
- POST to https://api.anthropic.com/v1/messages
- Model: claude-sonnet-4-6, max_tokens: 200
- Dynamic system prompt includes: personal vocab list, recent 5 messages
- User message: 'Complete this: "[currentText]"'
- Strict 5-second timeout → return [] on timeout
- Parse JSON response: {"predictions": [...]}
- Validate each prediction starts with typed prefix
- Return [] on any error (never throw)

NgramService (offline fallback):
- In-memory Map<String, Map<String, int>> trigram model
- Loads from assets/ngrams/english_trigrams.json
- Falls back to minimal hardcoded medical/care vocabulary model
- learnFromMessage(text): extracts words, updates trigram frequencies
- predict(text): returns List<PredictionResult> from trigram lookup

VocabularyService:
- Stores VocabularyEntryHive in Hive box 'vocabulary'
- learnFromMessage(text): updates word frequencies
- getTopVocabulary(limit): sorted by frequency

PredictionController (Riverpod StateNotifier):
- onTextChanged(text): shows loading state, debounces 300ms
- Tries Claude first, falls back to NgramService if offline or error
- Monitors ConnectivityPlus for online/offline detection
- updateContext(message): called after SPEAK, updates recent messages + vocab

PredictionCardsWidget:
- Shows 3 cards in a Row, each Expanded
- Each card is a gaze zone (registered with GazeEngine as 'prediction_0/1/2')
- Dwell fill animation identical to keyboard keys
- Shimmer loading state while Claude responds
- Animated slide-up when new predictions arrive
- Selecting calls keyboardController.insertPrediction(text)
```

---

## 🔊 PHASE 3: Voice + Emergency

### PROMPT 7 — Voice Engine
```
Build the voice synthesis system for ECHO.

TtsService (wrapping flutter_tts):
- Initialize: language en-US, rate 0.85, volume 1.0, pitch 1.0
- speak(text), stop()
- Stream<bool> speakingStream (broadcast)
- setRate(double) adjustable in settings

VoiceRecordingService:
- Records using 'record' package to m4a format
- Saves to getApplicationDocumentsDirectory()/voice_samples/sample_N.m4a
- startRecording(index), stopRecording() → returns path or null
- Validates: file must be >50KB minimum
- getSampleCount(), getRecordedSamples()

VoiceCloneService:
- Checks server at VOICE_CLONE_SERVER_URL/health (3s timeout)
- synthesize(): POST multipart with text + sample files to /synthesize
- Returns WAV file path, plays via just_audio
- Returns null on any failure (silent fallback to TTS)

VoiceSetupScreen:
- Shows 50 sentences from kVoiceSampleSentences constant
- Hold-to-record button (GestureDetector onTapDown/onTapUp)
- Red record button → gray stop
- Progress bar X/50 samples
- After 20+ samples: "Done — Use My Voice" button
- "Skip for now" link always visible

VoiceController (Riverpod StateNotifier):
- speak(text): if hasClonedVoice AND serverAvailable → clone, else TTS
- isSpeaking state property
- setVoiceRate(double)

Python FastAPI server voice_server/server.py:
- GET /health → {"status": "ok"}
- POST /synthesize → accepts text + audio files, returns WAV
- Uses Coqui TTS XTTS-v2 model
- Include requirements.txt with: fastapi, uvicorn, TTS, torch
```

---

### PROMPT 8 — Emergency Protocol
```
Build the complete emergency system for ECHO.

EmergencyContact model (Freezed):
- id, name, phoneNumber (international), relationship, sortOrder (1-5), 
  customMessage (optional)

EmergencyTriggerService:
- Monitors BlinkType events from GazeEngine
- Double blink = 2 single blinks within 800ms
- On double blink: start 5-second confirmation countdown
- Emits Stream<EmergencyTriggerEvent> with type and secondsRemaining
- cancel() stops the countdown and resets

LocationService:
- getCurrentPosition() with 10s timeout
- Returns Google Maps URL: https://maps.google.com/?q=lat,lng
- Returns null if permission denied or timeout

SmsService:
- Uses telephony package
- sendEmergencyToAll(contacts, patientName, locationUrl)
- Message: "EMERGENCY: [name] needs immediate help. [customMessage] Location: [url]"
- 200ms delay between each SMS (avoid rate limiting)

EmergencyController (Riverpod StateNotifier):
- Listens to EmergencyTriggerService stream
- On confirmationStarted: show overlay, start warning audio (0.5 vol)
- On emergencyFired: fetch GPS + send SMS + play emergency audio MAX vol + SOS vibration
- SOS vibration pattern: ...---... (3 short, 3 long, 3 short)
- cancelByPatient(): stops everything, resets state

EmergencyOverlayWidget:
- Full screen: red (#F85149) during confirmation countdown
- Giant pulsing warning icon
- Large countdown number with scale animation
- "CANCEL" button (white bg, red text) — very large, easy to gaze-select
- After sending: dark screen with green checkmark and "Alert sent!" + contact count
```

---

## 📋 PHASE 4: Phrases + Storage

### PROMPT 9 — Phrase Boards
```
Build the contextual phrase boards system for ECHO.

PhraseBoard model: id, userId, name, contextTrigger 
(morning/medical/evening/custom), triggerTime, active, List<PhraseItem>

PhraseItem model: id, boardId, text, iconName, sortOrder

PhraseContextService:
- getCurrentContext(DateTime) → returns context string based on time:
  05:00-10:00 → 'morning', 10:00-12:00 → 'late_morning'
  12:00-14:00 → 'lunch', 14:00-17:00 → 'afternoon'
  17:00-21:00 → 'evening', 21:00-05:00 → 'night'
- getSuggestedBoards(context) → returns matching boards
- Default boards loaded from assets/phrase_boards/default_boards.json

PhraseBoardsScreen:
- Shows 2-column grid of phrase boards
- Each board shows name and item count
- Tapping board → shows PhraseItemsView
- "Add Board" button for caregivers

PhraseItemWidget:
- Large button (min 80x80px) with icon and text
- Gaze-selectable (registered as zone)
- On selection: sends text directly to VoiceController.speak()

Default boards to include:
- Morning routine: "Good morning", "I slept well", "I need breakfast", 
  "I need my medication", "I need to be turned", "I need the bathroom"
- Medical: "I am in pain", "My pain is 7/10", "Please call the nurse", 
  "I need more medication", "I can't breathe well", "Please call the doctor"
- Emotional: "I love you", "Thank you", "I'm happy today", 
  "I miss you", "I'm worried", "I'm feeling better"
- Needs: "I need water", "I'm too hot", "I'm too cold", 
  "Please turn on TV", "Please turn off lights", "I want music"
```

---

### PROMPT 10 — Hive Local Database
```
Build the complete local data layer for ECHO using Hive.

Create Hive model files with @HiveType annotations:

UserProfileHive: userId, displayName, languageCode, role, 
  diagnosis, relationships(List<String>), createdAt

CalibrationDataHive: userId, deviceId, scaleX, scaleY, offsetX, offsetY, 
  centerX, centerY, accuracyScore, calibratedAt

VocabularyEntryHive: word, frequency, lastUsed, contextTags(List<String>)

CommunicationEntryHive: message, inputMethod, sentVia, timestamp, userId

PhraseBoardHive: id, name, contextTrigger, isDefault, items(List<PhraseItemHive>)

PhraseItemHive: text, iconName, sortOrder

Run hive_generator via build_runner to generate adapters.
Register ALL adapters in main.dart before openBox calls.

Open these boxes:
- 'user_profiles' (UserProfileHive)
- 'calibration_data' (CalibrationDataHive)  
- 'vocabulary' (VocabularyEntryHive)
- 'communication_history' (CommunicationEntryHive)
- 'phrase_boards' (PhraseBoardHive)
- 'app_settings' (dynamic)

Create repository classes for each box with basic CRUD operations.
Ensure all boxes can be opened without internet.
```

---

### PROMPT 11 — Supabase Backend
```
Set up the Supabase backend for ECHO.

Run these SQL migrations in Supabase SQL editor:

CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  role TEXT CHECK (role IN ('patient', 'caregiver')),
  display_name TEXT NOT NULL,
  language_code TEXT DEFAULT 'en',
  diagnosis TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_active TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE patient_caregiver_links (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id UUID REFERENCES users(id) ON DELETE CASCADE,
  caregiver_id UUID REFERENCES users(id) ON DELETE CASCADE,
  relationship TEXT,
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE calibration_profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  device_id TEXT NOT NULL,
  calibration_matrix JSONB,
  accuracy_score FLOAT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE vocabulary (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  word TEXT NOT NULL,
  frequency INTEGER DEFAULT 1,
  last_used TIMESTAMPTZ DEFAULT NOW(),
  context_tags TEXT[] DEFAULT '{}'
);

CREATE TABLE communication_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  input_method TEXT,
  sent_via TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE emergency_contacts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  phone_number TEXT NOT NULL,
  relationship TEXT,
  sort_order INTEGER,
  custom_message TEXT
);

CREATE TABLE session_analytics (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  session_start TIMESTAMPTZ,
  session_end TIMESTAMPTZ,
  total_messages INTEGER DEFAULT 0,
  avg_gaze_accuracy FLOAT,
  emergency_triggers INTEGER DEFAULT 0
);

Enable Row Level Security on all tables.
Add RLS policy: users can only SELECT/INSERT/UPDATE their own rows.
Caregivers can SELECT patient data for linked patients.

Create SupabaseRepository classes in Flutter for each table.
Handle Supabase auth with email/password.
Sync Hive data to Supabase when online.
```

---

## 👥 PHASE 5: Caregiver + Polish

### PROMPT 12 — Caregiver App
```
Build the caregiver companion portal for ECHO.

CaregiverDashboardScreen (separate auth):
- Shows linked patient's status card:
  Last active time, current tracking accuracy, battery level, is app open
- Recent messages panel: last 5 messages the patient sent
- Quick actions: Call patient, Schedule appointment, Add phrase board

PatientStatusScreen:
- Live: is face detected, current gaze accuracy (%)
- Today's stats: messages sent, words per minute, session duration
- Calibration quality chart (weekly accuracy trend using fl_chart)

AnalyticsScreen:
- fl_chart line graph: daily messages sent (30-day view)
- Engagement heatmap: hours of day vs. activity
- Accuracy trend: gaze tracking accuracy over time
- Export as PDF button

ScheduleScreen:
- Calendar view of upcoming events
- Add event: doctor visit, physio, family visit
- Events create context triggers for relevant phrase boards
- Example: adding "Doctor visit" at 2pm triggers medical phrase board at 1:45pm

ScheduleNotification:
- At 15 minutes before event: ECHO auto-suggests relevant phrase board
- Caregiver app receives notification when patient sends emergency

CaregiverSyncService:
- Listens to Supabase realtime subscription on communication_history
- Pushes local notification when new message sent by patient
- Syncs schedule to Supabase so ECHO app can read it
```

---

### PROMPT 13 — Complete Main Screen
```
Build the main communication screen that ties everything together.

MainCommunicationScreen layout (portrait, dark #0D1117):

TOP BAR (height 56px):
- Left: Patient name + gaze accuracy % indicator
- Center: Time display  
- Right: Camera thumbnail (80px) showing face tracking
- Background: #161B22 with bottom border

CAMERA/GAZE ZONE (takes up remaining top space):
- GazeCursorWidget overlay showing gaze position
- GazeEngine initialized with current screen size
- Face-not-detected warning: "Looking for your face..." banner

MESSAGE BAR (height 100px):
- MessageBarWidget showing current typed message
- Above keyboard, prominent position

PREDICTION CARDS (height 68px):
- PredictionCardsWidget with 3 Claude prediction cards
- Animate in when predictions available

KEYBOARD (remaining bottom space):
- GazeKeyboard with all keys
- Emergency indicator: small red dot blinks if emergency trigger service is active

STATUS BAR (bottom, 40px):
- Left: Offline indicator if no internet (n-gram active)
- Center: Dwell time setting slider (quick access)
- Right: Settings gear icon

EMERGENCY OVERLAY:
- EmergencyOverlayWidget covers full screen when triggered
- Sits in Stack above everything else

Initialize on screen load:
1. Request camera permission
2. Initialize GazeEngineController with screen size
3. Load calibration data and apply to gaze calculator
4. Initialize PredictionController
5. Initialize VoiceController
6. Initialize EmergencyController with saved contacts
7. Connect GazeEngine blink stream to EmergencyController

Handle app lifecycle (pause camera on background, resume on foreground).
Show calibration prompt if no calibration data exists.
```

---

### PROMPT 14 — UI Design System
```
Apply the complete ECHO design system throughout all screens.

Color constants in AppColors:
- background: #0D1117
- surface: #161B22
- surfaceElevated: #1C2128
- border: #30363D
- borderFocus: #58A6FF
- gazeBlue: #58A6FF  (gaze cursor, selection progress)
- selectionGreen: #3FB950  (confirmed selection)
- emergencyRed: #F85149  (emergency system)
- speakPurple: #BC8CFF  (voice speaking indicator)
- amber: #F0A742  (warnings)
- textPrimary: #E6EDF3
- textSecondary: #8B949E
- textMuted: #484F58

Typography (Inter font):
- displayLarge: 32px, bold, #E6EDF3
- displayMedium: 24px, semibold
- bodyLarge: 18px, regular
- bodyMedium: 16px, regular
- keyLabel: 24px, semibold (keyboard letters)
- minSize: 14px (WCAG AA compliant)

All interactive elements minimum size: 70x70px (WCAG AAA)
All text minimum contrast: 4.5:1 (WCAG AA)

Animations (flutter_animate):
- Key selection bloom: scale 1.0→1.15→1.0, duration 150ms
- Prediction card entry: slideY(0.3→0) + fadeIn, 200ms
- Gaze cursor: AnimatedContainer 50ms for smooth tracking
- Emergency countdown: scale 1.5→1.0 per tick

Apply consistent styling to: all cards, all buttons, all screens.
Add High Contrast Mode toggle in Settings that increases all contrast ratios.
```

---

### PROMPT 15 — Testing Suite
```
Create comprehensive tests for ECHO.

Unit tests (test/unit/):

gaze_calculator_test.dart:
- normalizeIrisPosition() returns 0.5 when iris is centered
- Smoothing reduces jitter (5 noisy inputs → smoother output)
- Head rotation compensation adjusts X by expected amount
- Calibration offsets applied correctly

blink_detector_test.dart:
- EAR < 0.20 for 80-600ms → single blink event
- Two single blinks within 800ms → double blink event
- EAR drop < 80ms → ignored (noise)
- Long blink (>600ms) → long blink event

calibration_service_test.dart:
- 15 calibration points collected in order
- computeCalibration() returns accuracyScore > 0.85 for good data
- perfectCalibrationData.accuracyScore == 1.0

ngram_service_test.dart:
- predict("I need") returns results starting with "I need"
- learnFromMessage() increases frequency of words
- Works when assets not available (minimal model)

Widget tests (test/widget/):

gaze_keyboard_test.dart:
- All 26 letters + special keys render without overflow
- Dwell progress set to 0.5 shows blue fill on key
- Key at dwellProgress 1.0 shows green selection state

prediction_cards_test.dart:
- Shows shimmer when predictions.isLoading == true
- Shows 3 cards when 3 predictions available
- Shows empty state when predictions list is empty

Integration tests (test/integration/):

communication_flow_test.dart:
- Full flow: gaze letter → keyboard selection → message → speak
- Emergency: double blink → confirmation overlay shows → countdown
- Prediction selection → message bar updated → SPEAK

Run all tests: flutter test
Run integration: flutter test integration_test/
```

---

### PROMPT 16 — App Store Deployment
```
Prepare ECHO for App Store and Play Store submission.

Android (Play Store):
1. Generate keystore:
   keytool -genkey -v -keystore ~/key.jks -keyalg RSA -keysize 2048 
   -validity 10000 -alias key

2. Create android/key.properties:
   storePassword=YOUR_PASSWORD
   keyPassword=YOUR_PASSWORD
   keyAlias=key
   storeFile=/home/user/key.jks

3. Update android/app/build.gradle with signing config

4. Build release APK:
   flutter build appbundle --release

5. Play Store listing:
   - Category: Medical
   - Content rating: Everyone
   - App description emphasizing accessibility + ALS/ALS use
   - Screenshots from app on physical device

iOS (App Store):
1. Create Apple Developer account ($99/year)
2. Create App ID in developer.apple.com
3. Create Distribution certificate and provisioning profile
4. In Xcode: set bundle ID, team, signing
5. Build: flutter build ipa --release
6. Upload via Transporter or Xcode organizer

7. App Store listing:
   - Category: Medical
   - Age rating: 4+
   - Privacy policy URL (required for health apps)
   - App description with accessibility keywords

Required metadata:
- App name: ECHO — Eye Gaze Communication
- Keywords: AAC, eye tracking, ALS, locked-in, communication, accessibility
- Support URL: Create GitHub repo or simple landing page
- Privacy Policy: Include what data is collected (local only, no tracking)
```

---

## 📌 Quick Reference: Key Code Patterns

### Registering a Gaze Zone (any widget can be a gaze target)
```dart
// In initState:
WidgetsBinding.instance.addPostFrameCallback((_) {
  final box = _globalKey.currentContext?.findRenderObject() as RenderBox?;
  if (box != null) {
    final pos = box.localToGlobal(Offset.zero);
    ref.read(gazeEngineProvider.notifier).registerKeyZone(
      'my_zone_id',
      Rect.fromLTWH(pos.dx, pos.dy, box.size.width, box.size.height),
    );
  }
});
```

### Listening to Dwell Progress for Visual Feedback
```dart
// In build:
final progressStream = ref.read(gazeEngineProvider.notifier).progressStream;
StreamBuilder<DwellProgress>(
  stream: progressStream,
  builder: (context, snapshot) {
    final progress = snapshot.data?.zone == 'my_zone_id' 
        ? snapshot.data!.progress 
        : 0.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 50),
      color: Color.lerp(Colors.grey, Colors.blue, progress),
    );
  },
)
```

### Making Any Screen Work Offline
```dart
// In controller:
ConnectivityPlus().onConnectivityChanged.listen((result) {
  _isOnline = result != ConnectivityResult.none;
  if (!_isOnline) {
    // Switch to local model
    _useLocalFallback = true;
  }
});
```

---

*Build ECHO. Ship it. Change lives.*
