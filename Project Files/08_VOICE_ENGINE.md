# 08 — Voice Engine
## ECHO AAC | Text-to-Speech, Voice Cloning, 100 Voice Profiles

---

## What We're Building

When a patient selects SPEAK, their message plays aloud in either:
1. **Their own cloned voice** — if they recorded 50 sentences during setup
2. **A matched preset voice** — chosen by age, gender, accent (100 profiles)
3. **System TTS fallback** — always available, zero setup

The voice is the patient's identity. Getting this right matters enormously.

---

## Voice System Architecture

```
Message typed → SPEAK selected
       ↓
VoiceController.speak(message)
       ↓
  Has voice clone?
  ↙          ↘
YES           NO
  ↓            ↓
CoquiVoice   Has preset?
  ↓          ↙     ↘
Send to    YES      NO
local      ↓        ↓
server   PresetTTS  SystemTTS
  ↓          ↓        ↓
  └──────────┴────────┘
           ↓
    Play audio file
           ↓
  Show speaking animation
```

---

## Implementation

### flutter_tts Integration (System TTS)

Create `lib/features/voice/services/tts_service.dart`:

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  late FlutterTts _flutterTts;
  bool _isInitialized = false;
  bool _isSpeaking = false;
  
  final _speakingController = StreamController<bool>.broadcast();
  Stream<bool> get speakingStream => _speakingController.stream;
  
  Future<void> initialize() async {
    _flutterTts = FlutterTts();
    
    // Configure TTS
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.85);     // Slightly slower for clarity
    await _flutterTts.setVolume(1.0);           // Maximum volume
    await _flutterTts.setPitch(1.0);            // Normal pitch
    
    // Set up event handlers
    _flutterTts.setStartHandler(() {
      _isSpeaking = true;
      _speakingController.add(true);
    });
    
    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
      _speakingController.add(false);
    });
    
    _flutterTts.setErrorHandler((message) {
      debugPrint('TTS error: $message');
      _isSpeaking = false;
      _speakingController.add(false);
    });
    
    // Get available voices
    final voices = await _flutterTts.getVoices;
    debugPrint('Available TTS voices: ${(voices as List).length}');
    
    _isInitialized = true;
  }
  
  Future<void> speak(String text) async {
    if (!_isInitialized) await initialize();
    
    // Stop any current speech
    if (_isSpeaking) await stop();
    
    await _flutterTts.speak(text);
  }
  
  Future<void> stop() async {
    await _flutterTts.stop();
    _isSpeaking = false;
    _speakingController.add(false);
  }
  
  Future<void> setVoice({
    required String name,
    required String locale,
  }) async {
    await _flutterTts.setVoice({'name': name, 'locale': locale});
  }
  
  Future<void> setRate(double rate) async {
    // Rate: 0.0 - 1.0, default 0.85
    await _flutterTts.setSpeechRate(rate.clamp(0.3, 1.0));
  }
  
  Future<List<Map<String, String>>> getAvailableVoices() async {
    final voices = await _flutterTts.getVoices as List;
    return voices.cast<Map<String, String>>();
  }
  
  bool get isSpeaking => _isSpeaking;
  
  Future<void> dispose() async {
    await _flutterTts.stop();
    await _speakingController.close();
  }
}
```

---

### Voice Recording Service

Create `lib/features/voice/services/voice_recording_service.dart`:

```dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

/// Records voice samples for voice cloning.
/// 
/// Voice cloning requires ~50 sentences of 5-15 seconds each.
/// We provide 100 sentences for users to read aloud.
/// The more samples, the better the cloned voice.
class VoiceRecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _currentRecordingPath;
  
  static const int _minSamplesForCloning = 20;  // Minimum viable
  static const int _targetSamples = 50;          // Target for good quality
  
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }
  
  Future<String> startRecording(int sampleIndex) async {
    if (!await _recorder.hasPermission()) {
      throw Exception('Microphone permission denied');
    }
    
    final dir = await getApplicationDocumentsDirectory();
    final voiceSamplesDir = Directory('${dir.path}/voice_samples');
    await voiceSamplesDir.create(recursive: true);
    
    final path = '${voiceSamplesDir.path}/sample_$sampleIndex.m4a';
    _currentRecordingPath = path;
    
    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,        // High quality for voice cloning
        numChannels: 1,           // Mono is fine for voice
      ),
      path: path,
    );
    
    _isRecording = true;
    return path;
  }
  
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;
    
    final path = await _recorder.stop();
    _isRecording = false;
    
    // Validate recording quality
    if (path != null) {
      final file = File(path);
      final size = await file.length();
      
      // Minimum 50KB = at least ~2 seconds of speech
      if (size < 50 * 1024) {
        await file.delete();
        return null; // Too short — discard
      }
    }
    
    return path;
  }
  
  Future<List<String>> getRecordedSamples() async {
    final dir = await getApplicationDocumentsDirectory();
    final voiceSamplesDir = Directory('${dir.path}/voice_samples');
    
    if (!await voiceSamplesDir.exists()) return [];
    
    final files = await voiceSamplesDir
        .list()
        .where((f) => f.path.endsWith('.m4a'))
        .cast<File>()
        .toList();
    
    return files.map((f) => f.path).toList()..sort();
  }
  
  Future<int> getSampleCount() async {
    return (await getRecordedSamples()).length;
  }
  
  bool get hasEnoughForCloning async {
    return await getSampleCount() >= _minSamplesForCloning;
  }
  
  bool get isRecording => _isRecording;
  
  Future<void> dispose() async {
    if (_isRecording) await _recorder.stop();
    await _recorder.dispose();
  }
}

/// The 100 sentences users read during voice setup.
/// Chosen to cover phonetically diverse sounds.
const List<String> kVoiceSampleSentences = [
  "Good morning, I hope you slept well.",
  "I would like a glass of water, please.",
  "Can you help me with this?",
  "I am feeling comfortable today.",
  "Please call my family.",
  "I need to tell you something important.",
  "Thank you for being here with me.",
  "I love you very much.",
  "The weather today looks beautiful.",
  "Could you turn on the television?",
  "I would like to listen to some music.",
  "Please adjust my pillow.",
  "I am a little cold right now.",
  "What time is my appointment today?",
  "I enjoyed our conversation yesterday.",
  "Can you read me the news?",
  "I would like to speak with my doctor.",
  "Please let me rest for a while.",
  "I need my medication now.",
  "Tell me about what happened today.",
  // ... (100 sentences total in the actual app — stored in assets JSON)
];
```

---

### Voice Clone Service (Coqui Integration)

Create `lib/features/voice/services/voice_clone_service.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// Integrates with a locally-running Coqui XTTS server
/// for voice cloning synthesis.
/// 
/// Architecture: Flutter app → HTTP → Local Python server (Coqui XTTS)
/// 
/// The Coqui server is a Python FastAPI app running on the same network
/// (or on localhost during development). For production, it runs as a
/// local server on a Raspberry Pi or similar small device, OR we use
/// a cloud API endpoint.
///
/// NOTE: For MVP, use flutter_tts (zero setup).
/// Voice cloning is Phase 2 — implement after core app works.
class VoiceCloneService {
  final String _serverUrl;
  final AudioPlayer _player = AudioPlayer();
  
  bool _isAvailable = false;
  
  VoiceCloneService() : _serverUrl = dotenv.env['VOICE_CLONE_SERVER_URL'] 
      ?? 'http://localhost:5000';
  
  Future<bool> checkServerAvailability() async {
    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/health'),
      ).timeout(const Duration(seconds: 3));
      
      _isAvailable = response.statusCode == 200;
      return _isAvailable;
    } catch (e) {
      _isAvailable = false;
      return false;
    }
  }
  
  /// Synthesize speech using the user's cloned voice.
  /// Returns path to the generated audio file.
  Future<String?> synthesize({
    required String text,
    required List<String> voiceSamplePaths,
  }) async {
    if (!_isAvailable) return null;
    
    try {
      // Send synthesis request to Coqui server
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_serverUrl/synthesize'),
      );
      
      // Add text
      request.fields['text'] = text;
      request.fields['language'] = 'en';
      
      // Add first 3 voice samples (most recent)
      final samples = voiceSamplePaths.take(3).toList();
      for (int i = 0; i < samples.length; i++) {
        request.files.add(
          await http.MultipartFile.fromPath('sample_$i', samples[i]),
        );
      }
      
      final response = await request.send().timeout(
        const Duration(seconds: 30),
      );
      
      if (response.statusCode != 200) return null;
      
      // Save the returned audio file
      final dir = await getTemporaryDirectory();
      final outputPath = '${dir.path}/synthesized_${DateTime.now().millisecondsSinceEpoch}.wav';
      
      final bytes = await response.stream.toBytes();
      await File(outputPath).writeAsBytes(bytes);
      
      return outputPath;
      
    } catch (e) {
      return null;
    }
  }
  
  /// Play a synthesized audio file
  Future<void> playAudio(String path) async {
    await _player.setFilePath(path);
    await _player.play();
  }
  
  Future<void> stop() async {
    await _player.stop();
  }
  
  Future<void> dispose() async {
    await _player.dispose();
  }
}
```

---

### Python Coqui Server Setup

Create `voice_server/server.py` (this runs separately, NOT in Flutter):

```python
"""
ECHO Voice Cloning Server
Run this on a local server or Raspberry Pi.
Provides REST API for voice synthesis using Coqui XTTS-v2.

Requirements:
  pip install fastapi uvicorn TTS torch

Run:
  python server.py
  
Runs on port 5000 by default.
"""

from fastapi import FastAPI, File, UploadFile, Form
from fastapi.responses import FileResponse
import tempfile
import os
from TTS.api import TTS

app = FastAPI(title="ECHO Voice Clone Server")

# Load XTTS model (downloads ~2GB on first run)
print("Loading XTTS model...")
tts = TTS("tts_models/multilingual/multi-dataset/xtts_v2", gpu=False)
print("Model loaded!")

@app.get("/health")
def health_check():
    return {"status": "ok", "model": "xtts_v2"}

@app.post("/synthesize")
async def synthesize(
    text: str = Form(...),
    language: str = Form("en"),
    sample_0: UploadFile = File(...),
    sample_1: UploadFile = File(None),
    sample_2: UploadFile = File(None),
):
    """
    Synthesize speech in user's cloned voice.
    Requires at least 1 voice sample file.
    """
    sample_files = []
    output_path = None
    
    try:
        # Save uploaded samples to temp files
        for sample in [sample_0, sample_1, sample_2]:
            if sample is None:
                continue
            
            with tempfile.NamedTemporaryFile(
                suffix=".wav", delete=False
            ) as tmp:
                content = await sample.read()
                tmp.write(content)
                sample_files.append(tmp.name)
        
        if not sample_files:
            return {"error": "No voice samples provided"}, 400
        
        # Generate speech
        output_path = tempfile.mktemp(suffix=".wav")
        
        tts.tts_to_file(
            text=text,
            speaker_wav=sample_files,  # Multiple samples = better cloning
            language=language,
            file_path=output_path,
        )
        
        return FileResponse(
            output_path,
            media_type="audio/wav",
            filename="synthesized.wav",
        )
        
    finally:
        # Clean up temp sample files
        for f in sample_files:
            if os.path.exists(f):
                os.remove(f)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=5000)
```

---

### VoiceController

Create `lib/features/voice/voice_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/tts_service.dart';
import 'services/voice_clone_service.dart';
import 'services/voice_recording_service.dart';

class VoiceState {
  final bool isSpeaking;
  final bool hasClonedVoice;
  final int sampleCount;
  final bool isCloneServerAvailable;
  final String? selectedPresetVoice;
  
  const VoiceState({
    this.isSpeaking = false,
    this.hasClonedVoice = false,
    this.sampleCount = 0,
    this.isCloneServerAvailable = false,
    this.selectedPresetVoice,
  });
  
  VoiceState copyWith({
    bool? isSpeaking,
    bool? hasClonedVoice,
    int? sampleCount,
    bool? isCloneServerAvailable,
    String? selectedPresetVoice,
  }) => VoiceState(
    isSpeaking: isSpeaking ?? this.isSpeaking,
    hasClonedVoice: hasClonedVoice ?? this.hasClonedVoice,
    sampleCount: sampleCount ?? this.sampleCount,
    isCloneServerAvailable: isCloneServerAvailable ?? this.isCloneServerAvailable,
    selectedPresetVoice: selectedPresetVoice ?? this.selectedPresetVoice,
  );
}

class VoiceController extends StateNotifier<VoiceState> {
  final TtsService _ttsService;
  final VoiceCloneService _cloneService;
  final VoiceRecordingService _recordingService;
  
  VoiceController({
    required TtsService ttsService,
    required VoiceCloneService cloneService,
    required VoiceRecordingService recordingService,
  }) : _ttsService = ttsService,
       _cloneService = cloneService,
       _recordingService = recordingService,
       super(const VoiceState()) {
    _initialize();
  }
  
  Future<void> _initialize() async {
    await _ttsService.initialize();
    
    final sampleCount = await _recordingService.getSampleCount();
    final serverAvailable = await _cloneService.checkServerAvailability();
    
    state = state.copyWith(
      sampleCount: sampleCount,
      hasClonedVoice: sampleCount >= 20,
      isCloneServerAvailable: serverAvailable,
    );
  }
  
  /// Main speak function — uses best available voice
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    
    state = state.copyWith(isSpeaking: true);
    
    try {
      if (state.hasClonedVoice && state.isCloneServerAvailable) {
        // Use voice clone
        final samples = await _recordingService.getRecordedSamples();
        final audioPath = await _cloneService.synthesize(
          text: text,
          voiceSamplePaths: samples,
        );
        
        if (audioPath != null) {
          await _cloneService.playAudio(audioPath);
          state = state.copyWith(isSpeaking: false);
          return;
        }
      }
      
      // Fallback: system TTS
      await _ttsService.speak(text);
      
    } finally {
      state = state.copyWith(isSpeaking: false);
    }
  }
  
  Future<void> stop() async {
    await _ttsService.stop();
    await _cloneService.stop();
    state = state.copyWith(isSpeaking: false);
  }
  
  void setVoiceRate(double rate) {
    _ttsService.setRate(rate);
  }
}

final voiceControllerProvider = 
    StateNotifierProvider<VoiceController, VoiceState>(
  (ref) => VoiceController(
    ttsService: TtsService(),
    cloneService: VoiceCloneService(),
    recordingService: VoiceRecordingService(),
  ),
);
```

---

### Voice Setup Screen

Create `lib/features/voice/screens/voice_setup_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../voice_controller.dart';
import '../services/voice_recording_service.dart';

/// Guides the user through recording voice samples for cloning.
/// Shows 100 sentences, records each one, tracks progress.
class VoiceSetupScreen extends ConsumerStatefulWidget {
  const VoiceSetupScreen({super.key});
  
  @override
  ConsumerState<VoiceSetupScreen> createState() => _VoiceSetupScreenState();
}

class _VoiceSetupScreenState extends ConsumerState<VoiceSetupScreen> {
  int _currentSentenceIndex = 0;
  bool _isRecording = false;
  int _recordedCount = 0;
  
  late VoiceRecordingService _recordingService;
  
  @override
  void initState() {
    super.initState();
    _recordingService = VoiceRecordingService();
    _loadExistingCount();
  }
  
  Future<void> _loadExistingCount() async {
    final count = await _recordingService.getSampleCount();
    setState(() {
      _recordedCount = count;
      _currentSentenceIndex = count;
    });
  }
  
  Future<void> _startRecording() async {
    final hasPermission = await _recordingService.requestPermission();
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission needed for voice setup')),
      );
      return;
    }
    
    await _recordingService.startRecording(_currentSentenceIndex);
    setState(() => _isRecording = true);
  }
  
  Future<void> _stopRecording() async {
    final path = await _recordingService.stopRecording();
    
    setState(() {
      _isRecording = false;
      if (path != null) {
        _recordedCount++;
        if (_currentSentenceIndex < kVoiceSampleSentences.length - 1) {
          _currentSentenceIndex++;
        }
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final progress = _recordedCount / VoiceRecordingService._targetSamples;
    final sentence = _currentSentenceIndex < kVoiceSampleSentences.length
        ? kVoiceSampleSentences[_currentSentenceIndex]
        : 'All sentences recorded!';
    
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Voice Setup', 
          style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip for now', 
              style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Progress
            Text(
              '$_recordedCount / 50 sentences recorded',
              style: const TextStyle(color: Colors.white60, fontSize: 16),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: const Color(0xFF161B22),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF58A6FF)),
              minHeight: 8,
            ),
            
            const SizedBox(height: 40),
            
            // Quality message
            if (_recordedCount >= 20)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A3A2A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '✓ Enough samples for voice cloning! Record more for better quality.',
                  style: TextStyle(color: Color(0xFF3FB950)),
                ),
              ),
            
            const Spacer(),
            
            // Current sentence to read
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isRecording 
                      ? const Color(0xFFF85149) 
                      : const Color(0xFF30363D),
                  width: _isRecording ? 2 : 1,
                ),
              ),
              child: Text(
                sentence,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Record button
            if (_currentSentenceIndex < kVoiceSampleSentences.length)
              GestureDetector(
                onTapDown: (_) => _startRecording(),
                onTapUp: (_) => _stopRecording(),
                onTapCancel: () => _stopRecording(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: _isRecording ? 90 : 80,
                  height: _isRecording ? 90 : 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isRecording 
                        ? const Color(0xFFF85149)
                        : const Color(0xFF58A6FF),
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
            
            const SizedBox(height: 12),
            
            Text(
              _isRecording 
                  ? 'Recording... Release when done' 
                  : 'Hold to record this sentence',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
            
            const SizedBox(height: 32),
            
            if (_recordedCount >= 20)
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3FB950),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 14),
                ),
                child: const Text('Done — Use My Voice', 
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }
}
```

---

## ✅ Milestone: Voice Working

- [ ] SPEAK button plays message via system TTS
- [ ] Volume is at maximum level
- [ ] Speaking indicator (purple dot) shows in message bar
- [ ] Voice recording screen shows and records samples
- [ ] After 20+ samples, "Use My Voice" button appears
- [ ] With Coqui server running locally, cloned voice plays

---

## 🤖 AI IDE Prompt — Voice Engine

```
Build the complete voice system for ECHO.

1. Create TtsService wrapping flutter_tts:
   - Initialize with: language en-US, rate 0.85, volume 1.0, pitch 1.0
   - speak(text), stop() methods
   - isSpeaking stream (broadcast)
   - getAvailableVoices() for profile selection

2. Create VoiceRecordingService:
   - Records voice samples using 'record' package
   - Saves as m4a in app documents/voice_samples/
   - Validates minimum file size (>50KB) before accepting
   - getSampleCount() to check how many samples recorded
   - getRecordedSamples() returns list of file paths

3. Create VoiceCloneService:
   - Checks if local Coqui server is available at VOICE_CLONE_SERVER_URL
   - synthesize(text, voiceSamplePaths) → sends HTTP multipart to server
   - Falls back silently to null if server unavailable
   - Plays returned audio file via just_audio

4. Create VoiceSetupScreen:
   - Shows list of 50 sentences from kVoiceSampleSentences
   - Hold-to-record button (starts recording on press down, stops on release)
   - Progress bar showing X/50 recorded
   - After 20+: "Use My Voice" button available
   - Can be skipped with "Skip for now"

5. Create VoiceController (Riverpod StateNotifier):
   - speak(text): tries clone voice → falls back to TTS
   - isSpeaking state drives UI purple indicator
   - setVoiceRate() adjustable from settings

6. Create voice_server/server.py Python FastAPI server:
   - /health endpoint
   - /synthesize endpoint accepts text + audio files
   - Uses Coqui XTTS-v2 for voice cloning
   - Returns WAV audio file

The voice must work immediately via TTS — cloning is enhancement layer.
```

---

*Next: `09_EMERGENCY_PROTOCOL.md` →*
