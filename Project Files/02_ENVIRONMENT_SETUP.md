# 02 — Environment Setup
## ECHO AAC | Flutter + All Dependencies

---

## Step 1: Install Flutter

### macOS
```bash
# Install via homebrew
brew install --cask flutter

# Or download directly
# https://docs.flutter.dev/get-started/install/macos

# Verify installation
flutter doctor -v

# You should see all green checkmarks except possibly:
# - Chrome (not needed)
# - VS Code (optional)
# Required: Flutter, Dart, Android toolchain, Xcode (for iOS)
```

### Windows
```powershell
# Download Flutter SDK from https://docs.flutter.dev/get-started/install/windows
# Extract to C:\flutter (NOT in Program Files — spaces cause issues)
# Add C:\flutter\bin to PATH
# Run:
flutter doctor -v
```

### Linux
```bash
sudo snap install flutter --classic
flutter doctor -v
```

---

## Step 2: Create the Project

```bash
# Create project — use underscore naming, not hyphens
flutter create echo_aac --org com.echoaac --platforms android,ios

cd echo_aac

# Initialize git immediately
git init
echo ".env" >> .gitignore
echo "*.jks" >> .gitignore
echo "key.properties" >> .gitignore
git add .
git commit -m "Initial Flutter project"

# Verify it runs
flutter run
```

---

## Step 3: Complete pubspec.yaml

Replace the entire `pubspec.yaml` with this:

```yaml
name: echo_aac
description: ECHO — Eye-gaze AAC communication app for locked-in patients
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.2.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

  # ═══════════════════════════════════════
  # EYE TRACKING & FACE DETECTION
  # ═══════════════════════════════════════
  google_mlkit_face_detection: ^0.9.0
  # Note: This provides 468 face landmarks including iris landmarks
  # which are the key to gaze estimation without dedicated eye tracker
  camera: ^0.10.5+9
  # Raw camera access at 60fps — critical for smooth gaze tracking

  # ═══════════════════════════════════════
  # STATE MANAGEMENT
  # ═══════════════════════════════════════
  flutter_riverpod: ^2.4.9
  riverpod_annotation: ^2.3.3
  hooks_riverpod: ^2.4.9
  flutter_hooks: ^0.20.4

  # ═══════════════════════════════════════
  # NAVIGATION
  # ═══════════════════════════════════════
  go_router: ^13.0.0

  # ═══════════════════════════════════════
  # AI & PREDICTION
  # ═══════════════════════════════════════
  http: ^1.2.0
  # Direct HTTP for Claude API (more control than SDK)
  dart_openai: ^4.1.0
  # Fallback prediction if needed

  # ═══════════════════════════════════════
  # VOICE & TEXT-TO-SPEECH
  # ═══════════════════════════════════════
  flutter_tts: ^3.8.5
  # Native TTS for all platforms
  record: ^5.0.4
  # Voice sample recording for voice cloning
  just_audio: ^0.9.36
  # Playback of cloned voice audio
  audioplayers: ^5.2.1
  # Emergency alert sounds
  path_provider: ^2.1.2
  # File paths for audio storage

  # ═══════════════════════════════════════
  # BACKEND & DATABASE
  # ═══════════════════════════════════════
  supabase_flutter: ^2.3.4
  hive_flutter: ^1.1.0
  hive: ^2.2.3
  # Local encrypted storage — works 100% offline

  # ═══════════════════════════════════════
  # EMERGENCY FEATURES
  # ═══════════════════════════════════════
  telephony: ^0.2.0
  # Send SMS without leaving app — uses device SMS
  geolocator: ^11.0.0
  # GPS coordinates for emergency message
  permission_handler: ^11.3.0
  # Request camera, microphone, location, SMS permissions

  # ═══════════════════════════════════════
  # AUTHENTICATION
  # ═══════════════════════════════════════
  local_auth: ^2.1.8
  # Biometric auth for caregiver portal
  flutter_secure_storage: ^9.0.0
  # Secure key storage

  # ═══════════════════════════════════════
  # UI & ANIMATIONS
  # ═══════════════════════════════════════
  flutter_animate: ^4.5.0
  # Smooth, chainable animations — gaze cursor bloom effect
  fl_chart: ^0.66.2
  # Caregiver analytics charts
  lottie: ^3.1.0
  # Lottie animations for onboarding
  shimmer: ^3.0.0
  # Loading skeleton screens
  google_fonts: ^6.1.0
  # Inter font

  # ═══════════════════════════════════════
  # HAPTICS
  # ═══════════════════════════════════════
  vibration: ^1.8.4
  # Fine-grained haptic control (pattern, duration, amplitude)
  # flutter's built-in HapticFeedback is too limited for this app

  # ═══════════════════════════════════════
  # ENVIRONMENT & CONFIG
  # ═══════════════════════════════════════
  flutter_dotenv: ^5.1.0
  # Load .env file for API keys

  # ═══════════════════════════════════════
  # UTILITIES
  # ═══════════════════════════════════════
  uuid: ^4.3.3
  intl: ^0.19.0
  collection: ^1.18.0
  rxdart: ^0.27.7
  # Stream utilities — essential for gaze data streams
  freezed_annotation: ^2.4.1
  json_annotation: ^4.8.1
  equatable: ^2.0.5
  logger: ^2.1.0
  connectivity_plus: ^6.0.2
  # Detect online/offline status for prediction fallback
  device_info_plus: ^10.1.0
  # Device ID for calibration profiles
  shared_preferences: ^2.2.2
  # Simple key-value prefs (app settings)

  # ═══════════════════════════════════════
  # SMART HOME (ADVANCED)
  # ═══════════════════════════════════════
  flutter_blue_plus: ^1.31.8
  # Bluetooth Low Energy for smart device control

dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  
  # Code generation
  build_runner: ^2.4.8
  riverpod_generator: ^2.3.9
  freezed: ^2.4.7
  json_serializable: ^6.7.1
  hive_generator: ^2.0.1
  
  # Testing
  mocktail: ^1.0.3
  fake_async: ^1.3.1
  
  # Linting
  flutter_lints: ^3.0.0
  very_good_analysis: ^6.0.0

flutter:
  uses-material-design: true

  assets:
    - assets/images/
    - assets/images/onboarding/
    - assets/audio/
    - assets/phrase_boards/
    - .env

  fonts:
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf
          weight: 400
        - asset: assets/fonts/Inter-Medium.ttf
          weight: 500
        - asset: assets/fonts/Inter-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/Inter-Bold.ttf
          weight: 700
```

---

## Step 4: Run Code Generation

```bash
# Get all dependencies
flutter pub get

# Run build_runner for code generation (Freezed, Hive, Riverpod)
dart run build_runner build --delete-conflicting-outputs

# If you need to re-run during development:
dart run build_runner watch --delete-conflicting-outputs
```

---

## Step 5: Android Configuration

### `android/app/src/main/AndroidManifest.xml`
Add ALL these permissions inside `<manifest>` tag:

```xml
<!-- Camera — required for eye tracking -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="true" />
<uses-feature android:name="android.hardware.camera.front" android:required="true" />

<!-- Microphone — for voice sample recording -->
<uses-permission android:name="android.permission.RECORD_AUDIO" />

<!-- SMS — for emergency alerts (works without internet) -->
<uses-permission android:name="android.permission.SEND_SMS" />
<uses-permission android:name="android.permission.READ_PHONE_STATE" />

<!-- Location — for emergency GPS -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<!-- Network -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<!-- Vibration — for haptic feedback -->
<uses-permission android:name="android.permission.VIBRATE" />

<!-- Wake lock — keep screen on during communication session -->
<uses-permission android:name="android.permission.WAKE_LOCK" />

<!-- Storage — for voice samples and local data -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" 
    android:maxSdkVersion="28" />
```

Also add inside `<application>` tag:
```xml
<!-- Keep screen on during communication sessions -->
android:keepScreenOn="true"

<!-- Allow cleartext for local voice server during development -->
android:usesCleartextTraffic="true"
```

### `android/app/build.gradle`
```gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        minSdkVersion 21    // MediaPipe requires 21+
        targetSdkVersion 34
        multiDexEnabled true
    }
    
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
    }
}
```

---

## Step 6: iOS Configuration

### `ios/Runner/Info.plist`
Add these keys inside the `<dict>`:

```xml
<!-- Camera -->
<key>NSCameraUsageDescription</key>
<string>ECHO needs camera access for eye gaze tracking to enable communication</string>

<!-- Microphone -->
<key>NSMicrophoneUsageDescription</key>
<string>ECHO needs microphone access to record your voice for personalized speech synthesis</string>

<!-- Location -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>ECHO needs location for emergency alerts to include your GPS position</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>ECHO needs background location for emergency alerts</string>

<!-- Keep screen on -->
<key>UIRequiresFullScreen</key>
<true/>

<!-- Background modes -->
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
    <string>audio</string>
</array>
```

---

## Step 7: Create `.env` File

```bash
# In project root — NEVER commit this file
touch .env
```

Contents of `.env`:
```env
ANTHROPIC_API_KEY=sk-ant-api03-YOUR_KEY_HERE
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.YOUR_KEY_HERE
VOICE_CLONE_SERVER_URL=http://localhost:5000
ENV=development
```

---

## Step 8: Initialize Services in main.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

// Import all Hive adapters
import 'data/local/models/user_profile_hive.dart';
import 'data/local/models/calibration_data_hive.dart';
import 'data/local/models/phrase_board_hive.dart';
import 'data/local/models/vocabulary_entry_hive.dart';
import 'data/local/models/communication_entry_hive.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables FIRST
  await dotenv.load(fileName: '.env');
  
  // Lock to portrait mode (eye tracking works best in portrait)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  // Keep screen on during the app
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );
  
  // Initialize Hive local database
  await Hive.initFlutter();
  
  // Register ALL Hive type adapters
  Hive.registerAdapter(UserProfileHiveAdapter());
  Hive.registerAdapter(CalibrationDataHiveAdapter());
  Hive.registerAdapter(PhraseBoardHiveAdapter());
  Hive.registerAdapter(VocabularyEntryHiveAdapter());
  Hive.registerAdapter(CommunicationEntryHiveAdapter());
  
  // Open Hive boxes
  await Hive.openBox<UserProfileHive>('user_profiles');
  await Hive.openBox<CalibrationDataHive>('calibration_data');
  await Hive.openBox<PhraseBoardHive>('phrase_boards');
  await Hive.openBox<VocabularyEntryHive>('vocabulary');
  await Hive.openBox<CommunicationEntryHive>('communication_history');
  await Hive.openBox('app_settings');
  
  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: OAuthFlow.pkce,
    ),
  );
  
  runApp(
    // Riverpod wrapper — enables all providers
    const ProviderScope(
      child: EchoApp(),
    ),
  );
}
```

---

## Step 9: Verify Setup Works

```bash
# Run on a connected device (NOT emulator — camera needed)
flutter run --release

# Expected output:
# ✓ Built successfully
# ✓ App launches
# ✓ No red screen errors

# Check for issues:
flutter analyze
```

---

## Step 10: Install Inter Font

```bash
# Download Inter from https://fonts.google.com/specimen/Inter
# Place files in assets/fonts/
# OR use google_fonts package (simpler):

# In your app theme, use:
# TextTheme produced by GoogleFonts.interTextTheme()
```

---

## Common Setup Errors & Fixes

### MediaPipe not finding faces
```
Error: MlKitException: No face found
Fix: Ensure front camera is being used, not rear
     Ensure adequate lighting
     Physical device required — emulators won't work
```

### Camera permission denied on Android
```
Error: CameraException: cameraPermission
Fix: Add permission_handler call before initializing camera
     Check AndroidManifest.xml has CAMERA permission
```

### Hive adapter not registered
```
Error: HiveError: Cannot write, unknown type
Fix: Run build_runner again: dart run build_runner build
     Ensure Hive.registerAdapter() is called BEFORE openBox()
```

### SMS not sending
```
Error: Telephony permission denied
Fix: Add SEND_SMS to AndroidManifest
     Request permission via permission_handler at runtime
     Note: iOS does not support programmatic SMS — use email fallback on iOS
```

---

## 🤖 AI IDE Prompt — Environment Setup

```
Set up a production-grade Flutter project called echo_aac for a medical 
AAC (eye-gaze communication) app.

1. Replace pubspec.yaml with the complete dependency list provided in 
   02_ENVIRONMENT_SETUP.md — include ALL dependencies as specified.

2. Create main.dart with proper async initialization of: dotenv, 
   Hive (with all adapters registered), Supabase, screen orientation 
   lock to portrait, and immersive mode.

3. Configure AndroidManifest.xml with all required permissions:
   CAMERA, RECORD_AUDIO, SEND_SMS, ACCESS_FINE_LOCATION, INTERNET,
   VIBRATE, WAKE_LOCK, READ_EXTERNAL_STORAGE

4. Configure ios/Runner/Info.plist with NSCameraUsageDescription,
   NSMicrophoneUsageDescription, NSLocationWhenInUseUsageDescription

5. Create .env template file (with placeholder values, never real keys)

6. Create the complete folder structure from 01_PROJECT_ARCHITECTURE.md
   with empty placeholder files and barrel exports

7. Run flutter pub get and confirm no dependency conflicts.

This is a medical app. Every permission must have a clear description 
string explaining WHY the permission is needed (not generic text).
```

---

*Next: `03_CAMERA_AND_MEDIAPIPE.md` →*
