# 01 — Project Architecture
## ECHO AAC | Full System Design

---

## 📐 High-Level Architecture

ECHO is built as a **multi-layer Flutter application** with the following layers:

```
┌─────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                    │
│         Flutter Widgets + Animations + UI State          │
├─────────────────────────────────────────────────────────┤
│                    FEATURE LAYER                         │
│   Gaze Engine │ Keyboard │ Voice │ Emergency │ Phrases   │
├─────────────────────────────────────────────────────────┤
│                    SERVICE LAYER                         │
│   MediaPipe │ Claude API │ Supabase │ TTS │ SMS │ GPS    │
├─────────────────────────────────────────────────────────┤
│                    DATA LAYER                            │
│         Hive (local) │ Supabase (cloud) │ Prefs          │
├─────────────────────────────────────────────────────────┤
│                    PLATFORM LAYER                        │
│         Camera │ Microphone │ Bluetooth │ Haptics         │
└─────────────────────────────────────────────────────────┘
```

---

## 📁 Complete Folder Structure

Every folder and file the project will contain. Create this structure on Day 1.

```
echo_aac/
│
├── lib/
│   │
│   ├── main.dart                          # App entry point
│   ├── app.dart                           # MaterialApp config, routes, theme
│   │
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_colors.dart            # All colors — ONE source of truth
│   │   │   ├── app_typography.dart        # All text styles
│   │   │   ├── app_dimensions.dart        # Spacing, sizes, breakpoints
│   │   │   └── app_strings.dart           # All user-facing strings (i18n ready)
│   │   │
│   │   ├── errors/
│   │   │   ├── exceptions.dart            # Custom exception classes
│   │   │   └── failures.dart              # Failure sealed classes
│   │   │
│   │   ├── extensions/
│   │   │   ├── context_extensions.dart    # BuildContext helpers
│   │   │   ├── string_extensions.dart     # String utilities
│   │   │   └── offset_extensions.dart     # Offset/math helpers for gaze
│   │   │
│   │   ├── services/
│   │   │   ├── haptic_service.dart        # Centralized haptics
│   │   │   ├── audio_service.dart         # Sound effects
│   │   │   └── permission_service.dart    # Camera/mic/location permissions
│   │   │
│   │   └── utils/
│   │       ├── logger.dart                # Structured logging
│   │       └── debouncer.dart             # Debounce utility for gaze
│   │
│   ├── features/
│   │   │
│   │   ├── onboarding/
│   │   │   ├── screens/
│   │   │   │   ├── welcome_screen.dart
│   │   │   │   ├── role_select_screen.dart      # Patient vs Caregiver
│   │   │   │   ├── permission_screen.dart
│   │   │   │   └── setup_complete_screen.dart
│   │   │   ├── widgets/
│   │   │   │   └── role_card.dart
│   │   │   └── onboarding_controller.dart
│   │   │
│   │   ├── calibration/
│   │   │   ├── screens/
│   │   │   │   ├── calibration_intro_screen.dart
│   │   │   │   ├── calibration_active_screen.dart
│   │   │   │   └── calibration_result_screen.dart
│   │   │   ├── models/
│   │   │   │   ├── calibration_point.dart
│   │   │   │   └── calibration_data.dart
│   │   │   ├── services/
│   │   │   │   └── calibration_service.dart
│   │   │   └── calibration_controller.dart
│   │   │
│   │   ├── gaze_engine/
│   │   │   ├── models/
│   │   │   │   ├── gaze_point.dart              # x,y,confidence,timestamp
│   │   │   │   ├── face_landmarks.dart           # 468 landmark wrapper
│   │   │   │   └── gaze_zone.dart                # Screen zone enum + bounds
│   │   │   ├── services/
│   │   │   │   ├── mediapipe_service.dart        # ML Kit face detection
│   │   │   │   ├── gaze_calculator.dart          # Vector math
│   │   │   │   ├── dwell_timer_service.dart      # Dwell logic
│   │   │   │   └── blink_detector.dart           # Blink detection
│   │   │   ├── widgets/
│   │   │   │   ├── camera_preview_widget.dart
│   │   │   │   ├── gaze_cursor_widget.dart       # The breathing circle
│   │   │   │   └── landmark_overlay.dart         # Debug overlay
│   │   │   └── gaze_engine_controller.dart
│   │   │
│   │   ├── keyboard/
│   │   │   ├── models/
│   │   │   │   ├── keyboard_layout.dart          # Letter positions
│   │   │   │   └── keyboard_key.dart             # Individual key model
│   │   │   ├── services/
│   │   │   │   └── keyboard_layout_service.dart  # Dynamic layout adaptation
│   │   │   ├── widgets/
│   │   │   │   ├── gaze_keyboard_widget.dart     # Main keyboard
│   │   │   │   ├── keyboard_key_widget.dart      # Single key
│   │   │   │   └── message_bar_widget.dart       # Typed message display
│   │   │   └── keyboard_controller.dart
│   │   │
│   │   ├── prediction/
│   │   │   ├── models/
│   │   │   │   └── prediction_result.dart
│   │   │   ├── services/
│   │   │   │   ├── claude_prediction_service.dart   # API calls
│   │   │   │   ├── ngram_service.dart               # Offline fallback
│   │   │   │   └── vocabulary_service.dart          # Personal vocab store
│   │   │   ├── widgets/
│   │   │   │   └── prediction_cards_widget.dart
│   │   │   └── prediction_controller.dart
│   │   │
│   │   ├── voice/
│   │   │   ├── models/
│   │   │   │   └── voice_profile.dart
│   │   │   ├── services/
│   │   │   │   ├── tts_service.dart               # Flutter TTS wrapper
│   │   │   │   ├── voice_clone_service.dart        # Coqui integration
│   │   │   │   └── voice_recording_service.dart    # Sample recording
│   │   │   ├── screens/
│   │   │   │   └── voice_setup_screen.dart
│   │   │   └── voice_controller.dart
│   │   │
│   │   ├── emergency/
│   │   │   ├── models/
│   │   │   │   └── emergency_contact.dart
│   │   │   ├── services/
│   │   │   │   ├── emergency_trigger_service.dart   # Double-blink detection
│   │   │   │   ├── sms_service.dart                 # Telephony
│   │   │   │   └── location_service.dart            # GPS
│   │   │   ├── screens/
│   │   │   │   └── emergency_setup_screen.dart
│   │   │   ├── widgets/
│   │   │   │   └── emergency_overlay_widget.dart
│   │   │   └── emergency_controller.dart
│   │   │
│   │   ├── phrases/
│   │   │   ├── models/
│   │   │   │   ├── phrase_board.dart
│   │   │   │   └── phrase_item.dart
│   │   │   ├── services/
│   │   │   │   └── phrase_context_service.dart      # Time/schedule aware
│   │   │   ├── screens/
│   │   │   │   └── phrase_boards_screen.dart
│   │   │   ├── widgets/
│   │   │   │   ├── phrase_board_widget.dart
│   │   │   │   └── phrase_item_widget.dart
│   │   │   └── phrases_controller.dart
│   │   │
│   │   ├── communication/
│   │   │   ├── models/
│   │   │   │   └── communication_entry.dart
│   │   │   ├── services/
│   │   │   │   └── history_service.dart
│   │   │   ├── screens/
│   │   │   │   ├── main_communication_screen.dart   # THE MAIN SCREEN
│   │   │   │   └── history_screen.dart
│   │   │   └── communication_controller.dart
│   │   │
│   │   └── caregiver/
│   │       ├── models/
│   │       │   └── caregiver_session.dart
│   │       ├── services/
│   │       │   └── caregiver_sync_service.dart
│   │       ├── screens/
│   │       │   ├── caregiver_dashboard_screen.dart
│   │       │   ├── patient_status_screen.dart
│   │       │   ├── analytics_screen.dart
│   │       │   └── schedule_screen.dart
│   │       └── caregiver_controller.dart
│   │
│   ├── data/
│   │   ├── local/
│   │   │   ├── hive_boxes.dart                  # Box name constants
│   │   │   ├── models/                          # Hive @HiveType models
│   │   │   │   ├── user_profile_hive.dart
│   │   │   │   ├── calibration_data_hive.dart
│   │   │   │   ├── phrase_board_hive.dart
│   │   │   │   ├── vocabulary_entry_hive.dart
│   │   │   │   └── communication_entry_hive.dart
│   │   │   └── repositories/
│   │   │       ├── local_user_repo.dart
│   │   │       ├── local_calibration_repo.dart
│   │   │       └── local_vocabulary_repo.dart
│   │   │
│   │   └── remote/
│   │       ├── supabase_client.dart
│   │       └── repositories/
│   │           ├── remote_user_repo.dart
│   │           ├── remote_caregiver_repo.dart
│   │           └── remote_analytics_repo.dart
│   │
│   └── shared/
│       ├── widgets/
│       │   ├── echo_button.dart              # Reusable accessible button
│       │   ├── echo_card.dart                # Card with warm styling
│       │   ├── echo_loading.dart             # Loading indicator
│       │   └── echo_snackbar.dart            # Feedback messages
│       └── providers/
│           └── app_providers.dart            # Riverpod/GetX provider setup
│
├── test/
│   ├── unit/
│   │   ├── gaze_calculator_test.dart
│   │   ├── blink_detector_test.dart
│   │   ├── calibration_service_test.dart
│   │   └── ngram_service_test.dart
│   ├── widget/
│   │   ├── gaze_keyboard_test.dart
│   │   └── prediction_cards_test.dart
│   └── integration/
│       └── communication_flow_test.dart
│
├── assets/
│   ├── images/
│   │   ├── onboarding/
│   │   └── icons/
│   ├── audio/
│   │   ├── selection_click.mp3
│   │   └── emergency_alert.mp3
│   ├── fonts/
│   │   └── Inter-Regular.ttf
│   │   └── Inter-Bold.ttf
│   └── phrase_boards/
│       └── default_boards.json              # Default phrase board data
│
├── android/
│   └── app/
│       └── src/main/AndroidManifest.xml     # Permissions (camera, sms, location)
│
├── ios/
│   └── Runner/
│       └── Info.plist                       # iOS permissions
│
├── pubspec.yaml
├── .env                                     # API keys (NEVER commit)
├── .gitignore
└── README.md
```

---

## 🔄 Data Flow Architecture

### Gaze → Letter Selection Flow
```
Camera Frame (60fps)
       ↓
MediaPipe Face Mesh
       ↓
468 Facial Landmarks Extracted
       ↓
GazeCalculator (iris position → normalized gaze vector)
       ↓
CalibrationService (apply calibration offset matrix)
       ↓
GazeZoneMapper (map vector → screen zone → keyboard key)
       ↓
DwellTimerService (accumulate dwell, check threshold)
       ↓
[SELECTION EVENT] → KeyboardController
       ↓
HapticService.selectionPulse()
       ↓
PredictionController.onLetterAdded(letter)
       ↓
ClaudeApiService.predict(currentWord, context) [async, non-blocking]
       ↓
UI State Update → Flutter rebuilds prediction cards
```

### Emergency Trigger Flow
```
Every Frame: BlinkDetector analyzes EAR (Eye Aspect Ratio)
       ↓
Blink event timestamped and stored in circular buffer (last 3 seconds)
       ↓
EmergencyTriggerService checks: 2 blinks within 800ms?
       ↓
[EMERGENCY EVENT]
       ↓
┌─────────────────────────────────────┐
│  1. LocationService.getCurrentGPS() │
│  2. SmsService.sendToAll5Contacts() │
│  3. TtsService.speak(maxVolume)     │
│  4. ScreenFlash overlay (red)       │
│  5. VibrationService.emergency()   │
└─────────────────────────────────────┘
       ↓
EmergencyOverlay displayed to patient (CANCEL option with 10s grace period)
```

### Claude Prediction Flow
```
User types "I nee"
       ↓
PredictionController buffers keystrokes
       ↓
After 300ms debounce: ClaudeApiService.predict()
       ↓
System Prompt includes:
  - Patient's name, relationships, common phrases
  - Last 5 messages sent (context)
  - Personal vocabulary learned
  - Current time/context
       ↓
Claude returns 3 predictions (JSON)
       ↓
If offline: NgramService.predict() instead
       ↓
PredictionCards update (animated slide-in)
       ↓
Patient gazes at prediction → full sentence sent to TTS
```

---

## 🗄️ Database Schema Overview

### Supabase Tables

```sql
-- Users (both patients and caregivers)
users (
  id UUID PRIMARY KEY,
  role TEXT CHECK (role IN ('patient', 'caregiver')),
  display_name TEXT,
  language_code TEXT DEFAULT 'en',
  created_at TIMESTAMPTZ,
  last_active TIMESTAMPTZ
)

-- Patient-Caregiver relationships
patient_caregiver_links (
  id UUID PRIMARY KEY,
  patient_id UUID REFERENCES users(id),
  caregiver_id UUID REFERENCES users(id),
  relationship TEXT,  -- 'family', 'professional', 'friend'
  active BOOLEAN DEFAULT true
)

-- Calibration data per device
calibration_profiles (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  device_id TEXT,
  calibration_matrix JSONB,  -- 15-point calibration offsets
  accuracy_score FLOAT,
  created_at TIMESTAMPTZ
)

-- Personal vocabulary
vocabulary (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  word TEXT,
  frequency INTEGER DEFAULT 1,
  last_used TIMESTAMPTZ,
  context_tags TEXT[]  -- ['medical', 'family', 'emotional']
)

-- Communication history
communication_history (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  message TEXT,
  input_method TEXT,  -- 'gaze', 'phrase_board', 'switch'
  sent_via TEXT,      -- 'voice', 'screen', 'both'
  created_at TIMESTAMPTZ
)

-- Phrase boards
phrase_boards (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  name TEXT,
  context_trigger TEXT,   -- 'morning', 'medical', 'evening', 'custom'
  trigger_time TIME,
  active BOOLEAN DEFAULT true
)

phrase_items (
  id UUID PRIMARY KEY,
  board_id UUID REFERENCES phrase_boards(id),
  text TEXT,
  icon_name TEXT,
  sort_order INTEGER
)

-- Emergency contacts
emergency_contacts (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  name TEXT,
  phone_number TEXT,
  relationship TEXT,
  sort_order INTEGER  -- 1-5, determines SMS order
)

-- Analytics (for caregiver insights)
session_analytics (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  session_start TIMESTAMPTZ,
  session_end TIMESTAMPTZ,
  total_messages INTEGER,
  avg_gaze_accuracy FLOAT,
  avg_words_per_minute FLOAT,
  emergency_triggers INTEGER DEFAULT 0
)
```

---

## 🔐 Security Architecture

### Patient Data Privacy Rules
- All local data stored in Hive with AES-256 encryption key derived from device biometric
- Supabase Row Level Security: users can ONLY access their own data
- Caregiver access requires patient approval (link invitation flow)
- Communication history is never sent to external servers except Supabase
- Claude API calls contain ONLY the typing context — no personally identifying data in the prompt unless user explicitly enables it
- Voice samples stored locally ONLY — never uploaded

### API Key Management
```dart
// Use flutter_dotenv — NEVER hardcode keys
// .env file (gitignored):
ANTHROPIC_API_KEY=sk-ant-...
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_ANON_KEY=eyJ...

// Load in main.dart:
await dotenv.load(fileName: ".env");
final apiKey = dotenv.env['ANTHROPIC_API_KEY']!;
```

---

## ⚡ Performance Requirements

These are non-negotiable targets:

| Metric | Target | How to Achieve |
|--------|--------|----------------|
| Camera pipeline latency | < 33ms | Process on isolate thread |
| Gaze update rate | 60fps | Native camera, no transcoding |
| Gaze-to-cursor lag | < 50ms | Direct state update, no animation delay |
| Letter selection feedback | < 16ms | Haptic on main thread |
| Claude prediction return | < 1.5s | Debounce + streaming response |
| App cold start | < 3s | Lazy load heavy services |
| Emergency trigger to SMS | < 2s | Pre-loaded contacts, async SMS |
| Offline mode activation | Instant | Always-on local model |

---

## 🌐 State Management Architecture

Use **Riverpod** (recommended) or GetX. This document uses Riverpod.

```dart
// Core providers
final gazeEngineProvider = StateNotifierProvider<GazeEngineController, GazeState>
final keyboardProvider = StateNotifierProvider<KeyboardController, KeyboardState>
final predictionProvider = StateNotifierProvider<PredictionController, PredictionState>
final voiceProvider = StateNotifierProvider<VoiceController, VoiceState>
final emergencyProvider = StateNotifierProvider<EmergencyController, EmergencyState>
final calibrationProvider = StateNotifierProvider<CalibrationController, CalibrationState>
final caregiverProvider = StateNotifierProvider<CaregiverController, CaregiverState>
```

Each controller manages a single domain. No cross-controller dependencies — they communicate via a shared `AppEventBus`.

---

## 🤖 AI IDE Prompt — Architecture Setup

```
You are building ECHO, a production-grade AAC (Augmentative and Alternative 
Communication) Flutter app for locked-in patients. 

Create the complete Flutter project structure exactly as specified below.
Use Riverpod for state management. Use clean architecture with feature-based 
folder organization.

Create the following:
1. The complete folder structure from lib/ as documented
2. Barrel export files (index.dart) for each feature folder
3. The core app.dart with MaterialApp, GoRouter navigation, and Riverpod ProviderScope
4. The main.dart that initializes: Hive, Supabase, dotenv, and runs the app
5. All pubspec.yaml dependencies as listed in 02_ENVIRONMENT_SETUP.md

This app handles medical communication for paralyzed patients. Code quality 
and reliability are paramount. Add comprehensive error handling everywhere.
Follow SOLID principles. Use sealed classes for state.

Generate placeholder screens for every route so navigation works immediately,
even before features are built.
```

---

*Next: `02_ENVIRONMENT_SETUP.md` →*
