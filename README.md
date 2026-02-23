# ECHO AAC

## Eye-Gaze Communication App

ECHO is a production-grade AAC (Augmentative and Alternative Communication) app built with Flutter and MediaPipe. It allows people with limited mobility to communicate using only their eyes.

### Key Features

- **Gaze Keyboard**: Type with your eyes using high-accuracy tracking.
- **Claude AI Predictions**: Contextual sentence completion powered by Anthropic's Claude.
- **Voice Synthesis**: Personal voice cloning and system TTS.
- **Emergency Protocol**: Double-blink to trigger SOS alerts via SMS and GPS.
- **Offline First**: Works 100% offline for core communication.

### Architecture

- **Layered Design**: Clean Architecture with Presentation, Feature, Service, and Data layers.
- **State Management**: Governed by Riverpod.
- **Local Storage**: Encrypted Hive boxes.
- **Cloud Backend**: Supabase for sync and caregiver monitoring.

---

_Built to change lives._
