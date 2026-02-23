# 06 — Gaze Keyboard
## ECHO AAC | Full Adaptive Eye-Gaze Keyboard

---

## What We're Building

The gaze keyboard is ECHO's primary communication tool. It is not a normal keyboard. It must be:
- **Large-keyed** — minimum 80x80px per key (gaze precision requires larger targets)
- **Adaptive** — most-likely letters drift toward gaze center (reduces eye travel)
- **Self-registering** — each key tells the GazeEngine its screen bounds
- **Visually feedback-rich** — dwell progress shown on every key being gazed

---

## Keyboard Layout Design

### Base QWERTY Layout (adapted for gaze)
We DON'T use standard QWERTY directly. We arrange keys by **frequency of use** in a circular/adaptive pattern. But we START with QWERTY for familiarity.

```
Layout zones (6 rows × 7 columns max):
Row 1:  Q  W  E  R  T  Y  U
Row 2:  I  O  P  A  S  D  F
Row 3:  G  H  J  K  L  Z  X
Row 4:  C  V  B  N  M  ⌫  
Row 5:  [SPACE — full width]
Row 6:  [SPEAK] [?!,. panel] [PHRASES] [CLEAR]

Special zones:
- ⌫ (backspace): bottom right of letters
- SPACE: wide bar
- SPEAK: full message aloud
- Numeric/symbol toggle
```

---

## Implementation

### KeyboardLayout Model

Create `lib/features/keyboard/models/keyboard_layout.dart`:

```dart
import 'package:flutter/material.dart';

enum KeyType { letter, backspace, space, speak, phrases, clear, symbols, number }

class KeyboardKey {
  final String id;          // Unique ID for gaze zone registration
  final String display;     // What shows on the key
  final String value;       // What gets inserted (might differ from display)
  final KeyType type;
  final double relativeWidth; // 1.0 = normal key width
  Color? customColor;
  
  const KeyboardKey({
    required this.id,
    required this.display,
    required this.value,
    required this.type,
    this.relativeWidth = 1.0,
    this.customColor,
  });
  
  static KeyboardKey letter(String char) => KeyboardKey(
    id: 'key_${char.toLowerCase()}',
    display: char,
    value: char.toLowerCase(),
    type: KeyType.letter,
  );
  
  static const KeyboardKey backspace = KeyboardKey(
    id: 'key_backspace',
    display: '⌫',
    value: '\b',
    type: KeyType.backspace,
  );
  
  static const KeyboardKey space = KeyboardKey(
    id: 'key_space',
    display: 'SPACE',
    value: ' ',
    type: KeyType.space,
    relativeWidth: 5.0,
  );
  
  static const KeyboardKey speak = KeyboardKey(
    id: 'key_speak',
    display: '🔊 SPEAK',
    value: 'SPEAK',
    type: KeyType.speak,
    relativeWidth: 2.5,
    customColor: Color(0xFF3FB950),
  );
  
  static const KeyboardKey phrases = KeyboardKey(
    id: 'key_phrases',
    display: 'PHRASES',
    value: 'PHRASES',
    type: KeyType.phrases,
    relativeWidth: 2.0,
    customColor: Color(0xFF58A6FF),
  );
  
  static const KeyboardKey clear = KeyboardKey(
    id: 'key_clear',
    display: 'CLEAR',
    value: 'CLEAR',
    type: KeyType.clear,
    relativeWidth: 2.0,
    customColor: Color(0xFFF85149),
  );
}

class KeyboardLayout {
  final List<List<KeyboardKey>> rows;
  
  const KeyboardLayout({required this.rows});
  
  static KeyboardLayout get standard => KeyboardLayout(rows: [
    // Row 1
    [
      KeyboardKey.letter('Q'), KeyboardKey.letter('W'), KeyboardKey.letter('E'),
      KeyboardKey.letter('R'), KeyboardKey.letter('T'), KeyboardKey.letter('Y'),
      KeyboardKey.letter('U'),
    ],
    // Row 2
    [
      KeyboardKey.letter('I'), KeyboardKey.letter('O'), KeyboardKey.letter('P'),
      KeyboardKey.letter('A'), KeyboardKey.letter('S'), KeyboardKey.letter('D'),
      KeyboardKey.letter('F'),
    ],
    // Row 3
    [
      KeyboardKey.letter('G'), KeyboardKey.letter('H'), KeyboardKey.letter('J'),
      KeyboardKey.letter('K'), KeyboardKey.letter('L'), KeyboardKey.letter('Z'),
      KeyboardKey.letter('X'),
    ],
    // Row 4
    [
      KeyboardKey.letter('C'), KeyboardKey.letter('V'), KeyboardKey.letter('B'),
      KeyboardKey.letter('N'), KeyboardKey.letter('M'), KeyboardKey.backspace,
    ],
    // Row 5 — Space bar
    [KeyboardKey.space],
    // Row 6 — Action bar
    [KeyboardKey.speak, KeyboardKey.phrases, KeyboardKey.clear],
  ]);
}
```

---

### Keyboard Key Widget

Create `lib/features/keyboard/widgets/keyboard_key_widget.dart`:

```dart
import 'package:flutter/material.dart';
import '../models/keyboard_layout.dart';
import '../../gaze_engine/services/dwell_timer_service.dart';

/// A single key on the gaze keyboard.
/// 
/// Visual behavior:
/// - Default: dark card with letter text
/// - Being gazed: fills with blue progress
/// - Selected: green flash + haptic feedback
/// - After select: returns to default after animation
class GazeKeyWidget extends StatefulWidget {
  final KeyboardKey key;
  final double width;
  final double height;
  final double dwellProgress; // 0.0 = no dwell, 1.0 = selected
  final bool isSelected;
  final Function(GlobalKey widgetKey) onLayoutComplete; // For zone registration
  
  const GazeKeyWidget({
    super.key,
    required this.key,
    required this.width,
    required this.height,
    required this.dwellProgress,
    required this.isSelected,
    required this.onLayoutComplete,
  });
  
  @override
  State<GazeKeyWidget> createState() => _GazeKeyWidgetState();
}

class _GazeKeyWidgetState extends State<GazeKeyWidget>
    with SingleTickerProviderStateMixin {
  final GlobalKey _keyGlobalKey = GlobalKey();
  
  @override
  void initState() {
    super.initState();
    // Register bounds after first layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onLayoutComplete(_keyGlobalKey);
    });
  }
  
  Color get _backgroundColor {
    if (widget.dwellProgress > 0) {
      return Color.lerp(
        const Color(0xFF161B22),
        const Color(0xFF1A3A5C),
        widget.dwellProgress,
      )!;
    }
    return widget.key.customColor?.withOpacity(0.15) ?? 
           const Color(0xFF161B22);
  }
  
  Color get _borderColor {
    if (widget.isSelected) return const Color(0xFF3FB950);
    if (widget.dwellProgress > 0) {
      return Color.lerp(
        const Color(0xFF30363D),
        const Color(0xFF58A6FF),
        widget.dwellProgress,
      )!;
    }
    return const Color(0xFF30363D);
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      key: _keyGlobalKey,
      width: widget.width,
      height: widget.height,
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _borderColor,
          width: widget.dwellProgress > 0 ? 2 : 1,
        ),
        boxShadow: widget.isSelected ? [
          BoxShadow(
            color: const Color(0xFF3FB950).withOpacity(0.4),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ] : null,
      ),
      child: Stack(
        children: [
          // Dwell fill — fills from bottom up
          if (widget.dwellProgress > 0)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: widget.height * widget.dwellProgress,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(9),
                    top: Radius.circular(2),
                  ),
                  color: const Color(0xFF58A6FF).withOpacity(0.15),
                ),
              ),
            ),
          
          // Key label
          Center(
            child: Text(
              widget.key.display,
              style: TextStyle(
                color: widget.isSelected 
                    ? const Color(0xFF3FB950) 
                    : Colors.white.withOpacity(0.9),
                fontSize: _getFontSize(),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  double _getFontSize() {
    switch (widget.key.type) {
      case KeyType.letter: return 24;
      case KeyType.space: return 16;
      case KeyType.speak: return 18;
      default: return 16;
    }
  }
}
```

---

### Main Gaze Keyboard Widget

Create `lib/features/keyboard/widgets/gaze_keyboard_widget.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';
import '../models/keyboard_layout.dart';
import '../keyboard_controller.dart';
import '../../gaze_engine/gaze_engine_controller.dart';
import 'keyboard_key_widget.dart';

/// The main gaze-controlled keyboard.
/// 
/// This widget:
/// 1. Renders all keyboard keys in a grid layout
/// 2. Registers each key's screen bounds with GazeEngine
/// 3. Listens to gaze dwell events and updates key visual states
/// 4. Fires selection events when dwell completes
class GazeKeyboard extends ConsumerStatefulWidget {
  const GazeKeyboard({super.key});
  
  @override
  ConsumerState<GazeKeyboard> createState() => _GazeKeyboardState();
}

class _GazeKeyboardState extends ConsumerState<GazeKeyboard> {
  final KeyboardLayout _layout = KeyboardLayout.standard;
  final Map<String, double> _dwellProgresses = {};
  final Set<String> _selectedKeys = {};
  
  @override
  void initState() {
    super.initState();
    
    // Listen to dwell progress — update visual state of keys
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gazeEngine = ref.read(gazeEngineProvider.notifier);
      
      // Subscribe to progress updates
      gazeEngine.progressStream.listen((progress) {
        if (mounted) {
          setState(() {
            _dwellProgresses.clear();
            if (progress.zone.isNotEmpty) {
              _dwellProgresses[progress.zone] = progress.progress;
            }
          });
        }
      });
      
      // Subscribe to selections
      gazeEngine.selectionStream.listen((zoneId) {
        _onKeySelected(zoneId);
      });
    });
  }
  
  void _onKeySelected(String keyId) {
    // Find the key with this ID
    KeyboardKey? selectedKey;
    for (final row in _layout.rows) {
      for (final key in row) {
        if (key.id == keyId) {
          selectedKey = key;
          break;
        }
      }
    }
    
    if (selectedKey == null) return;
    
    // Haptic feedback — different patterns for different key types
    _triggerHaptic(selectedKey.type);
    
    // Flash selected state
    setState(() => _selectedKeys.add(keyId));
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _selectedKeys.remove(keyId));
    });
    
    // Handle the key press
    ref.read(keyboardControllerProvider.notifier).handleKeyPress(selectedKey);
  }
  
  void _triggerHaptic(KeyType type) async {
    if (!await Vibration.hasVibrator() ?? false) return;
    
    switch (type) {
      case KeyType.letter:
        Vibration.vibrate(duration: 30, amplitude: 80);
        break;
      case KeyType.space:
        Vibration.vibrate(duration: 50, amplitude: 100);
        break;
      case KeyType.backspace:
        Vibration.vibrate(pattern: [0, 20, 20, 20], amplitudes: [0, 100, 0, 100]);
        break;
      case KeyType.speak:
        Vibration.vibrate(duration: 100, amplitude: 200);
        break;
      default:
        Vibration.vibrate(duration: 40, amplitude: 120);
    }
  }
  
  void _registerKeyZone(GlobalKey globalKey, String keyId) {
    final RenderBox? box = 
        globalKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    
    final position = box.localToGlobal(Offset.zero);
    final size = box.size;
    
    final rect = Rect.fromLTWH(
      position.dx,
      position.dy,
      size.width,
      size.height,
    );
    
    ref.read(gazeEngineProvider.notifier).registerKeyZone(keyId, rect);
  }
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final keyWidth = constraints.maxWidth / 7; // 7 columns max
        const keyHeight = 70.0;
        
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: _layout.rows.map((row) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((key) {
                final width = keyWidth * key.relativeWidth;
                final progress = _dwellProgresses[key.id] ?? 0.0;
                final isSelected = _selectedKeys.contains(key.id);
                
                return GazeKeyWidget(
                  key: ValueKey(key.id),
                  key: key,
                  width: width,
                  height: keyHeight,
                  dwellProgress: progress,
                  isSelected: isSelected,
                  onLayoutComplete: (gk) => _registerKeyZone(gk, key.id),
                );
              }).toList(),
            );
          }).toList(),
        );
      },
    );
  }
}
```

---

### Message Bar Widget

Create `lib/features/keyboard/widgets/message_bar_widget.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../keyboard_controller.dart';

/// Shows the currently typed message with cursor.
/// When SPEAK is selected, this animates and the voice plays.
class MessageBarWidget extends ConsumerWidget {
  const MessageBarWidget({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keyboard = ref.watch(keyboardControllerProvider);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF30363D),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Voice indicator (purple pulse when speaking)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: keyboard.isSpeaking 
                  ? const Color(0xFFBC8CFF) 
                  : Colors.transparent,
              boxShadow: keyboard.isSpeaking ? [
                const BoxShadow(
                  color: Color(0x80BC8CFF),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ] : null,
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Message text
          Expanded(
            child: Text(
              keyboard.currentMessage.isEmpty 
                  ? 'Start looking at letters to type...' 
                  : keyboard.currentMessage,
              style: TextStyle(
                color: keyboard.currentMessage.isEmpty 
                    ? Colors.white.withOpacity(0.3)
                    : Colors.white.withOpacity(0.9),
                fontSize: 20,
                letterSpacing: 0.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // Word count
          if (keyboard.currentMessage.isNotEmpty)
            Text(
              '${keyboard.wordCount}w',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}
```

---

### KeyboardController

Create `lib/features/keyboard/keyboard_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/keyboard_layout.dart';
import '../voice/voice_controller.dart';
import '../prediction/prediction_controller.dart';

class KeyboardState {
  final String currentMessage;
  final bool isSpeaking;
  final bool isCapitalized;
  
  const KeyboardState({
    this.currentMessage = '',
    this.isSpeaking = false,
    this.isCapitalized = true, // Start with capital
  });
  
  int get wordCount => currentMessage.trim().isEmpty 
      ? 0 
      : currentMessage.trim().split(RegExp(r'\s+')).length;
  
  KeyboardState copyWith({
    String? currentMessage,
    bool? isSpeaking,
    bool? isCapitalized,
  }) => KeyboardState(
    currentMessage: currentMessage ?? this.currentMessage,
    isSpeaking: isSpeaking ?? this.isSpeaking,
    isCapitalized: isCapitalized ?? this.isCapitalized,
  );
}

class KeyboardController extends StateNotifier<KeyboardState> {
  final VoiceController _voiceController;
  final PredictionController _predictionController;
  
  KeyboardController({
    required VoiceController voiceController,
    required PredictionController predictionController,
  }) : _voiceController = voiceController,
       _predictionController = predictionController,
       super(const KeyboardState());
  
  void handleKeyPress(KeyboardKey key) {
    switch (key.type) {
      case KeyType.letter:
        _addLetter(key.value);
        break;
      case KeyType.space:
        _addSpace();
        break;
      case KeyType.backspace:
        _handleBackspace();
        break;
      case KeyType.speak:
        _speakCurrentMessage();
        break;
      case KeyType.clear:
        _clearMessage();
        break;
      case KeyType.phrases:
        _openPhraseBoards();
        break;
      default:
        break;
    }
  }
  
  /// Called when user selects a Claude prediction
  void insertPrediction(String prediction) {
    state = state.copyWith(currentMessage: prediction);
    _predictionController.updateContext(prediction);
  }
  
  void _addLetter(String letter) {
    final newChar = state.isCapitalized ? letter.toUpperCase() : letter;
    final newMessage = state.currentMessage + newChar;
    
    state = state.copyWith(
      currentMessage: newMessage,
      isCapitalized: false, // After first letter, no more auto-cap
    );
    
    // Trigger prediction update
    _predictionController.onTextChanged(newMessage);
  }
  
  void _addSpace() {
    if (state.currentMessage.isNotEmpty && 
        !state.currentMessage.endsWith(' ')) {
      state = state.copyWith(
        currentMessage: state.currentMessage + ' ',
      );
      _predictionController.onTextChanged(state.currentMessage);
    }
  }
  
  void _handleBackspace() {
    if (state.currentMessage.isEmpty) return;
    
    final newMessage = state.currentMessage.substring(
      0, state.currentMessage.length - 1,
    );
    
    state = state.copyWith(currentMessage: newMessage);
    _predictionController.onTextChanged(newMessage);
  }
  
  void _speakCurrentMessage() async {
    if (state.currentMessage.trim().isEmpty) return;
    
    state = state.copyWith(isSpeaking: true);
    
    await _voiceController.speak(state.currentMessage);
    
    // Save to communication history
    await _saveToCommunicationHistory(state.currentMessage);
    
    state = state.copyWith(
      isSpeaking: false,
      currentMessage: '',
      isCapitalized: true, // Next message starts with capital
    );
  }
  
  void _clearMessage() {
    state = state.copyWith(
      currentMessage: '',
      isCapitalized: true,
    );
    _predictionController.onTextChanged('');
  }
  
  void _openPhraseBoards() {
    // Navigate to phrase boards — handled by navigation
    // This fires a navigation event
  }
  
  Future<void> _saveToCommunicationHistory(String message) async {
    // Save to Hive local storage
    // Implementation in data layer
  }
}

final keyboardControllerProvider = 
    StateNotifierProvider<KeyboardController, KeyboardState>(
  (ref) => KeyboardController(
    voiceController: ref.read(voiceControllerProvider.notifier),
    predictionController: ref.read(predictionControllerProvider.notifier),
  ),
);
```

---

## ✅ Milestone: Keyboard Working

You know this step is complete when:
- [ ] All 26 letters appear on keyboard with proper layout
- [ ] Looking at a letter shows dwell fill animation
- [ ] After 600ms dwell, letter appears in message bar
- [ ] Haptic feedback fires on selection
- [ ] Backspace works correctly
- [ ] Space bar is wide and easy to select
- [ ] SPEAK button triggers (voice not implemented yet — just log to console)
- [ ] CLEAR empties the message bar

---

## 🤖 AI IDE Prompt — Gaze Keyboard

```
Build the complete gaze-controlled keyboard for ECHO.

1. Create KeyboardKey and KeyboardLayout models with:
   - Letter keys A-Z (all), Backspace, Space, Speak, Phrases, Clear
   - Space bar has relativeWidth: 5.0
   - Speak button is green (#3FB950)
   - Clear button is red (#F85149)
   - Standard 6-row layout as documented

2. Create GazeKeyWidget that:
   - Shows dwell fill animation (fills from bottom, blue→green)
   - Scales and flashes green when selected
   - Registers its GlobalKey bounds with GazeEngine after first layout
   - Has minimum 70px height for gaze accuracy

3. Create GazeKeyboard widget that:
   - Lays out all keys using LayoutBuilder (7 columns wide)
   - Listens to GazeEngine progressStream for dwell updates per key
   - Listens to GazeEngine selectionStream for key selections
   - Triggers haptic on selection (letter=30ms, space=50ms, speak=100ms)
   - Registers ALL key bounds with GazeEngine on first build

4. Create MessageBarWidget that:
   - Shows current typed message in large white text
   - Shows "Start looking at letters to type..." placeholder
   - Shows purple pulsing dot when voice is speaking
   - Shows word count

5. Create KeyboardController (Riverpod StateNotifier) that:
   - Manages currentMessage string
   - Handles: letter add, space, backspace, speak, clear
   - On SPEAK: calls VoiceController, saves to history, clears message
   - On letter: triggers PredictionController.onTextChanged()
   - Handles capitalization (first letter of message is always capitalized)

The keyboard must be usable with only gaze — no touch fallback needed,
but add touch fallback during development for faster testing.
```

---

*Next: `07_CLAUDE_AI_INTEGRATION.md` →*
