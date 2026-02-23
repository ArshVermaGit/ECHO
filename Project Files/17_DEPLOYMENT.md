# 17 — Deployment
## ECHO AAC | App Store + Play Store Submission

---

See PROMPT 16 in `18_AI_IDE_PROMPTS.md` for complete deployment commands.

---

## App Store Listing Strategy

### Why App Store Approval Matters
Medical apps face extra scrutiny. ECHO is classified as a general "productivity" / "utilities" app, NOT a medical device. This is key — submitting as a medical device (FDA regulated) requires clinical evidence. ECHO should be described as a communication accessibility app.

### Description Template

```
ECHO — Eye Gaze Communication

ECHO helps people with limited mobility communicate using only their eyes. 
Powered by Google's MediaPipe technology, ECHO tracks eye movement through 
your phone's front camera to enable hands-free typing.

DESIGNED FOR:
• ALS and motor neuron disease
• Locked-in syndrome
• Cerebral palsy
• Spinal cord injury
• Anyone with limited hand/speech function

KEY FEATURES:
• Gaze-controlled keyboard — type with your eyes
• AI-powered sentence prediction — type faster
• Voice synthesis — speak in your own cloned voice
• Emergency alerts — double-blink sends GPS + SMS to caregivers
• Works offline — no internet needed for core features
• Caregiver companion app included

PRIVACY:
All personal data stored locally on your device.
Communication history never leaves your device without your permission.

ECHO is a communication tool, not a medical device. 
Always consult healthcare professionals for medical decisions.
```

### Required Assets
- App icon: 1024x1024px, no transparency
- Screenshots: 6.7" iPhone (1290x2796), iPad Pro (2048x2732)
- Preview video: 30 seconds showing gaze tracking in action

---

## Privacy Policy Requirements

Medical-adjacent apps must have privacy policies. Key points:
- Camera data processed locally, never uploaded
- Communication history: local only (cloud backup opt-in)
- No advertising, no tracking
- Voice samples: local only
- Emergency contacts: stored securely, used only for emergency

Host on GitHub Pages or simple landing page.

---

## Post-Launch Monitoring

```dart
// Add crash reporting
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

// Add in main.dart:
FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

// Log emergency events (anonymized) for quality monitoring
// Track: gaze accuracy distribution, calibration scores, session lengths
// Use Firebase Analytics (privacy-preserving, no user IDs)
```
