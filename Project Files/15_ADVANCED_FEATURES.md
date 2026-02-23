# 15 — Advanced Features
## ECHO AAC | Switch Access, Smart Home, Emotion Detection, Multilingual

---

## Feature 1: Switch Access Mode

For patients with ANY remaining motor function (one finger, toe, cheek puff):

```dart
// SwitchAccessService detects any accelerometer/touch input
// Maps to same selection events as gaze dwell
// Patient can scan through keyboard with switch input
// Works alongside gaze tracking — whichever fires first selects

class SwitchAccessService {
  // Monitor accelerometer for head nod gesture
  // Monitor any screen touch (for patients with limited hand movement)
  // Each switch input = advance highlight + selection after 2nd input
}
```

---

## Feature 2: Smart Home Integration

```dart
// Uses flutter_blue_plus for Bluetooth LE
// Integrates with Matter protocol for modern smart home devices

class SmartHomeService {
  // Control Philips Hue (via hub API)
  // Control smart plugs
  // Send commands to smart speaker (Spotify, volume, etc.)
  
  // Gaze patterns:
  // Look at "LIGHTS" zone → shows room selector
  // Select room → shows on/off/dim controls
  // Each is a gaze zone
}
```

---

## Feature 3: Emotion Detection

```dart
// MediaPipe also provides: smile probability, eye openness patterns
// We build an emotional state monitor

class EmotionDetectionService {
  // Signs of discomfort: furrowed brow (landmarks), frequent blinking
  // Signs of distress: rapid eye movement, decreased EAR
  // Alert caregiver app via Supabase realtime when sustained distress detected
  // Patient can see their detected emotion and confirm/dismiss
  
  // This is AMBIENT — patient doesn't activate it
  // Caregiver receives gentle notification, not alarm
}
```

---

## Feature 4: 40-Language Support

```dart
// Flutter localizations for UI strings
// Keyboard layout adapts to language:
// - Spanish: adds Ñ, Á, É, Í, Ó, Ú
// - French: adds accents panel
// - Arabic: right-to-left layout
// - Chinese: uses pinyin input with character suggestions

// Language selection in Settings
// Claude API called with language context
// TTS uses locale-appropriate voice

// Priority languages for Phase 2:
// Spanish, French, German, Portuguese, Arabic, 
// Hindi, Mandarin, Japanese, Italian, Russian
```

---

## Feature 5: Legacy Journaling

```dart
// CommunicationHistoryScreen shows all past messages
// Patient can "save" any message to their journal
// Journal entries: timestamped, searchable
// Export journal as PDF (text in patient's own words, date/time stamped)
// "Letters" feature: patient writes letter to loved one over multiple sessions
// Voice playback: hear cloned voice reading saved journal entries
```

---

## 🤖 AI IDE Prompt — Advanced Features

```
Implement Phase 2 advanced features for ECHO.

1. Switch access: detect any touch or accelerometer gesture as alternative 
   input, maps to same zone selection as gaze dwell

2. Smart home: flutter_blue_plus integration with simple Bluetooth LE 
   device control, gaze-selectable room/device/action grid

3. Emotion detection: use MediaPipe eye blink patterns and facial muscle 
   landmarks to detect prolonged distress, alert caregiver via Supabase

4. Multilingual: add Spanish and French as first two additional languages,
   flutter_localizations setup, keyboard layout swaps accent panels,
   Claude API includes language context in system prompt

5. Legacy journal: save marked messages to encrypted journal, 
   export to PDF, voice playback of journal entries using cloned voice
```
