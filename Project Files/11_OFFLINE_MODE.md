# 11 — Offline Mode
## ECHO AAC | Full Offline Operation — No Internet Required for Core Features

---

## Architecture: Online vs Offline

ECHO must work 100% offline. Every core feature has an offline path:

| Feature | Online | Offline |
|---------|--------|---------|
| Gaze tracking | ✅ MediaPipe (local) | ✅ Same |
| Calibration | ✅ Local | ✅ Same |
| Typing | ✅ Local | ✅ Same |
| Prediction | Claude API | N-gram model (local) |
| Voice output | TTS or clone server | System TTS (local) |
| Emergency SMS | ✅ GSM (no internet needed) | ✅ Same |
| Phrase boards | ✅ Local Hive | ✅ Same |
| History save | Hive → Supabase sync | Hive only (sync later) |
| Caregiver updates | Supabase realtime | Queued for sync |

---

## Connectivity Manager

```dart
// lib/core/services/connectivity_service.dart

class ConnectivityService {
  final _connectivityController = StreamController<bool>.broadcast();
  Stream<bool> get isOnlineStream => _connectivityController.stream;
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  void initialize() {
    Connectivity().onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;
      _isOnline = result != ConnectivityResult.none;
      
      if (wasOnline != _isOnline) {
        _connectivityController.add(_isOnline);
        
        if (_isOnline) {
          // Back online — trigger sync
          _syncPendingData();
        }
      }
    });
  }

  Future<void> _syncPendingData() async {
    // Sync pending Hive records to Supabase
    // Implemented in SupabaseRepository.syncPending()
  }
}
```

---

## Offline Indicator in UI

Show a small offline banner when internet is unavailable:

```dart
// Show in main screen status bar
if (!isOnline) 
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    color: const Color(0xFF1C2128),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.wifi_off, size: 12, color: Color(0xFFF0A742)),
        const SizedBox(width: 4),
        const Text(
          'Offline — predictions using local model',
          style: TextStyle(color: Color(0xFFF0A742), fontSize: 11),
        ),
      ],
    ),
  )
```

---

## N-gram Model Asset

Create `assets/ngrams/english_trigrams.json` with medical/care vocabulary:

```json
{
  "i need": {
    "help": 150, "water": 120, "medicine": 100, "rest": 80,
    "you": 90, "the": 70, "to": 200, "a": 160
  },
  "i want": {
    "to": 200, "water": 80, "food": 70, "sleep": 60,
    "music": 50, "you": 90
  },
  "can you": {
    "help": 150, "please": 120, "call": 100, "come": 80,
    "hear": 70, "turn": 90
  },
  "please help": {
    "me": 200, "call": 80, "fix": 60
  },
  "i am": {
    "fine": 100, "tired": 90, "in": 150, "feeling": 120,
    "happy": 80, "worried": 70, "okay": 60
  },
  "i feel": {
    "sick": 100, "tired": 90, "pain": 80, "better": 70,
    "cold": 60, "hot": 60, "dizzy": 50
  },
  "thank you": {
    "very": 150, "so": 130, "for": 120
  },
  "i love": {
    "you": 300
  }
}
```

---

## 🤖 AI IDE Prompt — Offline Mode

```
Implement complete offline mode for ECHO.

1. ConnectivityService: monitors network state via connectivity_plus,
   broadcasts Stream<bool> isOnline, triggers Supabase sync when back online

2. Ensure NgramService loads from assets/ngrams/english_trigrams.json
   and falls back to hardcoded minimal model if asset unavailable

3. Add offline indicator banner in MainCommunicationScreen when isOnline=false

4. Create sync queue: when data written to Hive while offline, 
   mark as pending sync, sync to Supabase when connectivity restored

5. Verify: app works fully with WiFi disabled (gaze, typing, TTS, phrases, emergency)
```
