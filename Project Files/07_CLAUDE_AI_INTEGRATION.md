# 07 — Claude AI Integration
## ECHO AAC | Predictive Text, Vocabulary Learning, Offline Fallback

---

## What We're Building

Claude predicts what the user wants to say before they finish typing. For a patient who types 2-3 letters per minute with their eyes, having a good prediction that completes the sentence is life-changing — it might reduce a 3-minute typing session to 20 seconds.

---

## The System Prompt Design

The system prompt is everything. It tells Claude who this person is, how they speak, and what context they're in. The better the prompt, the better the predictions.

### Building a Dynamic System Prompt

```dart
String buildSystemPrompt({
  required UserProfile user,
  required List<String> recentMessages,
  required List<VocabularyEntry> personalVocab,
  required String currentTime,
}) {
  return '''
You are the predictive text engine for ${user.displayName}'s AAC communication device.
${user.displayName} uses eye-gaze to type, which is slow — each letter takes significant effort.
Your ONLY job is to predict what they want to say and offer completions.

ABOUT ${user.displayName.toUpperCase()}:
- Diagnosis: ${user.diagnosis ?? 'Not specified'}
- Primary language: ${user.languageCode}
- Communication style: ${user.communicationStyle ?? 'Direct and clear'}
- Important relationships: ${user.relationships.join(', ')}
- Common topics: ${user.commonTopics.join(', ')}

PERSONAL VOCABULARY (words they use frequently):
${personalVocab.take(50).map((v) => '"${v.word}" (${v.frequency}x)').join(', ')}

RECENT MESSAGES SENT (for context):
${recentMessages.take(5).map((m) => '- "$m"').join('\n')}

CURRENT CONTEXT:
- Time: $currentTime
- Date: ${DateTime.now().toLocal().toString().split(' ')[0]}

RULES:
1. Return EXACTLY 3 predictions as JSON
2. Each prediction is a COMPLETE sentence or phrase (not just word continuations)
3. Predictions must start with the letters already typed
4. Predict based on context — time of day, recent topics, personal vocabulary
5. Keep predictions SHORT — max 12 words (typing is effortful, fewer words = better)
6. One prediction should be a NEEDS prediction ("I need...", "Can you...", "Please...")
7. Never predict anything embarrassing, offensive, or out of character
8. Format: {"predictions": ["full sentence 1", "full sentence 2", "full sentence 3"]}
''';
}
```

---

## Implementation

### ClaudeApiService

Create `lib/features/prediction/services/claude_prediction_service.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/prediction_result.dart';
import '../../data/local/models/vocabulary_entry_hive.dart';

class ClaudePredictionService {
  static const String _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const String _model = 'claude-sonnet-4-6'; // Use Sonnet for speed
  static const int _maxTokens = 200; // Predictions are short
  
  final http.Client _httpClient;
  String? _apiKey;
  
  ClaudePredictionService({http.Client? httpClient}) 
      : _httpClient = httpClient ?? http.Client();
  
  void initialize() {
    _apiKey = dotenv.env['ANTHROPIC_API_KEY'];
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('ANTHROPIC_API_KEY not found in .env');
    }
  }
  
  /// Get 3 sentence predictions from Claude
  /// Returns empty list on error (falls back to n-gram)
  Future<List<PredictionResult>> predict({
    required String currentText,
    required String systemPrompt,
    String? previousMessage,
  }) async {
    if (_apiKey == null) return [];
    if (currentText.trim().isEmpty) return [];
    
    try {
      final response = await _httpClient.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _apiKey!,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': _model,
          'max_tokens': _maxTokens,
          'system': systemPrompt,
          'messages': [
            {
              'role': 'user',
              'content': 'Complete this: "$currentText"',
            },
          ],
        }),
      ).timeout(
        const Duration(seconds: 5), // Strict timeout — don't block typing
        onTimeout: () => http.Response('{"error": "timeout"}', 408),
      );
      
      if (response.statusCode != 200) {
        debugPrint('Claude API error: ${response.statusCode}');
        return [];
      }
      
      final data = jsonDecode(response.body);
      final content = data['content'] as List?;
      if (content == null || content.isEmpty) return [];
      
      final text = content.first['text'] as String? ?? '';
      
      return _parsePredictions(text, currentText);
      
    } catch (e) {
      debugPrint('Claude prediction error: $e');
      return [];
    }
  }
  
  List<PredictionResult> _parsePredictions(String responseText, String prefix) {
    try {
      // Extract JSON from response
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(responseText);
      if (jsonMatch == null) return [];
      
      final json = jsonDecode(jsonMatch.group(0)!);
      final predictions = (json['predictions'] as List?)?.cast<String>() ?? [];
      
      return predictions
          .where((p) => p.toLowerCase().startsWith(prefix.toLowerCase().trim()))
          .take(3)
          .map((p) => PredictionResult(
                text: p,
                confidence: 0.9,
                source: PredictionSource.claude,
              ))
          .toList();
          
    } catch (e) {
      debugPrint('Failed to parse predictions: $e');
      return [];
    }
  }
}
```

---

### N-gram Offline Fallback

Create `lib/features/prediction/services/ngram_service.dart`:

```dart
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/prediction_result.dart';

/// Offline prediction using pre-trained n-gram model.
/// This runs locally with zero latency and zero internet.
/// 
/// The model is a trigram (3-word context window) trained on:
/// - Common English sentences
/// - Medical/caregiving vocabulary
/// - Personal vocabulary learned from user
class NgramService {
  // In-memory trigram frequency map
  // Map<"word1 word2", Map<"word3", frequency>>
  Map<String, Map<String, int>> _trigrams = {};
  bool _isLoaded = false;
  
  Future<void> initialize() async {
    // Load pre-built ngram data from assets
    try {
      final data = await rootBundle.loadString('assets/ngrams/english_trigrams.json');
      final Map<String, dynamic> json = jsonDecode(data);
      
      _trigrams = json.map((key, value) => MapEntry(
        key,
        (value as Map<String, dynamic>).map((k, v) => MapEntry(k, v as int)),
      ));
      
      _isLoaded = true;
    } catch (e) {
      // Fail silently — use empty model
      _trigrams = _buildMinimalModel();
      _isLoaded = true;
    }
  }
  
  /// Update model with new user vocabulary
  void learnFromMessage(String message) {
    final words = message.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    
    for (int i = 0; i < words.length - 2; i++) {
      final context = '${words[i]} ${words[i + 1]}';
      final nextWord = words[i + 2];
      
      _trigrams[context] ??= {};
      _trigrams[context]![nextWord] = (_trigrams[context]![nextWord] ?? 0) + 1;
    }
  }
  
  List<PredictionResult> predict(String currentText) {
    if (!_isLoaded) return [];
    
    final words = currentText.toLowerCase().trim().split(RegExp(r'\s+'));
    if (words.length < 2) return _predictFromUnigram(words.last);
    
    final context = '${words[words.length - 2]} ${words[words.length - 1]}';
    final candidates = _trigrams[context];
    
    if (candidates == null || candidates.isEmpty) {
      // Fall back to bigram
      return _predictFromBigram(words.last);
    }
    
    // Sort by frequency, return top 3
    final sorted = candidates.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sorted.take(3).map((e) => PredictionResult(
      text: '${currentText.trim()} ${e.key}',
      confidence: e.value / (candidates.values.reduce((a, b) => a + b)),
      source: PredictionSource.ngram,
    )).toList();
  }
  
  List<PredictionResult> _predictFromBigram(String lastWord) {
    final results = <PredictionResult>[];
    int found = 0;
    
    for (final entry in _trigrams.entries) {
      if (entry.key.endsWith(lastWord)) {
        final best = entry.value.entries.reduce((a, b) => a.value > b.value ? a : b);
        results.add(PredictionResult(
          text: '${entry.key} ${best.key}',
          confidence: 0.5,
          source: PredictionSource.ngram,
        ));
        if (++found >= 3) break;
      }
    }
    
    return results;
  }
  
  List<PredictionResult> _predictFromUnigram(String prefix) {
    // Return common sentence starters that begin with the typed letters
    const starters = [
      'I need ', 'Can you ', 'I want ', 'Please ', 'Thank you ',
      'I am ', 'I feel ', 'Help me ', 'I love you', 'Yes', 'No',
    ];
    
    return starters
        .where((s) => s.toLowerCase().startsWith(prefix.toLowerCase()))
        .take(3)
        .map((s) => PredictionResult(
              text: s,
              confidence: 0.4,
              source: PredictionSource.ngram,
            ))
        .toList();
  }
  
  Map<String, Map<String, int>> _buildMinimalModel() {
    // Minimal hardcoded model for basic use without assets
    return {
      'i need': {'help': 10, 'water': 8, 'medicine': 7},
      'i want': {'to': 15, 'water': 8, 'food': 6},
      'can you': {'help': 12, 'please': 10, 'call': 8},
      'i am': {'fine': 10, 'tired': 8, 'in pain': 7},
      'please help': {'me': 15, 'call': 8},
      'thank you': {'very much': 12, 'so much': 8},
      'i feel': {'sick': 10, 'tired': 9, 'pain': 8, 'better': 6},
    };
  }
}
```

---

### Vocabulary Learning Service

Create `lib/features/prediction/services/vocabulary_service.dart`:

```dart
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/local/models/vocabulary_entry_hive.dart';

/// Learns and stores the user's personal vocabulary.
/// Every time the user sends a message, we extract words and update frequencies.
/// High-frequency words get priority in predictions.
class VocabularyService {
  final Box<VocabularyEntryHive> _box;
  
  VocabularyService(this._box);
  
  Future<void> learnFromMessage(String message) async {
    final words = _extractWords(message);
    
    for (final word in words) {
      if (word.length < 2) continue; // Skip single chars
      
      final existing = _box.values
          .where((e) => e.word.toLowerCase() == word.toLowerCase())
          .firstOrNull;
      
      if (existing != null) {
        existing.frequency++;
        existing.lastUsed = DateTime.now();
        await existing.save();
      } else {
        await _box.add(VocabularyEntryHive(
          word: word.toLowerCase(),
          frequency: 1,
          lastUsed: DateTime.now(),
          contextTags: _inferContextTags(word),
        ));
      }
    }
  }
  
  List<VocabularyEntryHive> getTopVocabulary({int limit = 100}) {
    final entries = _box.values.toList()
      ..sort((a, b) => b.frequency.compareTo(a.frequency));
    return entries.take(limit).toList();
  }
  
  List<String> _extractWords(String message) {
    return message
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
  }
  
  List<String> _inferContextTags(String word) {
    const medicalWords = ['pain', 'medicine', 'doctor', 'nurse', 'help', 'hospital'];
    const emotionalWords = ['love', 'happy', 'sad', 'feel', 'miss', 'need'];
    const familyWords = ['mom', 'dad', 'family', 'child', 'wife', 'husband'];
    
    final tags = <String>[];
    if (medicalWords.contains(word)) tags.add('medical');
    if (emotionalWords.contains(word)) tags.add('emotional');
    if (familyWords.contains(word)) tags.add('family');
    return tags;
  }
}
```

---

### Prediction Cards Widget

Create `lib/features/prediction/widgets/prediction_cards_widget.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../prediction_controller.dart';
import '../../keyboard/keyboard_controller.dart';

/// Shows 3 Claude predictions as selectable cards above the keyboard.
/// 
/// These are one of the most important UI elements — selecting a prediction
/// card can save 30+ keystrokes. It must be:
/// - Easy to see (high contrast, large font)
/// - Easy to select with gaze (large tap/gaze targets)
/// - Quick to update (smooth animation on change)
class PredictionCardsWidget extends ConsumerWidget {
  const PredictionCardsWidget({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final predictions = ref.watch(predictionControllerProvider);
    
    if (predictions.predictions.isEmpty && !predictions.isLoading) {
      return const SizedBox(height: 8);
    }
    
    return Container(
      height: 68,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: predictions.isLoading
          ? _buildLoadingState()
          : Row(
              children: predictions.predictions
                  .take(3)
                  .toList()
                  .asMap()
                  .entries
                  .map((entry) => Expanded(
                        child: PredictionCard(
                          prediction: entry.value.text,
                          index: entry.key,
                          onSelected: () {
                            ref.read(keyboardControllerProvider.notifier)
                                .insertPrediction(entry.value.text);
                          },
                        ).animate().fadeIn(
                              delay: Duration(milliseconds: entry.key * 60),
                              duration: const Duration(milliseconds: 200),
                            ).slideY(begin: 0.3, end: 0),
                      ))
                  .toList(),
            ),
    );
  }
  
  Widget _buildLoadingState() {
    return Row(
      children: List.generate(3, (i) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(10),
          ),
        ).animate(onPlay: (c) => c.repeat()).shimmer(
          duration: const Duration(seconds: 1),
          color: const Color(0xFF30363D),
        ),
      )),
    );
  }
}

class PredictionCard extends ConsumerStatefulWidget {
  final String prediction;
  final int index;
  final VoidCallback onSelected;
  
  const PredictionCard({
    super.key,
    required this.prediction,
    required this.index,
    required this.onSelected,
  });
  
  @override
  ConsumerState<PredictionCard> createState() => _PredictionCardState();
}

class _PredictionCardState extends ConsumerState<PredictionCard> {
  double _dwellProgress = 0.0;
  final GlobalKey _cardKey = GlobalKey();
  
  @override
  void initState() {
    super.initState();
    
    // Register zone with gaze engine after layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Register gaze zone for this prediction card
      // Zone ID: 'prediction_0', 'prediction_1', 'prediction_2'
      final zoneId = 'prediction_${widget.index}';
      final box = _cardKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        final pos = box.localToGlobal(Offset.zero);
        // Register zone with gaze engine
        ref.read(gazeEngineProvider.notifier).registerKeyZone(
          zoneId,
          Rect.fromLTWH(pos.dx, pos.dy, box.size.width, box.size.height),
        );
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      key: _cardKey,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Color.lerp(
          const Color(0xFF161B22),
          const Color(0xFF1A3A2A),
          _dwellProgress,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Color.lerp(
            const Color(0xFF30363D),
            const Color(0xFF3FB950),
            _dwellProgress,
          )!,
          width: 1.5,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            widget.prediction,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
```

---

### PredictionController

Create `lib/features/prediction/prediction_controller.dart`:

```dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/claude_prediction_service.dart';
import 'services/ngram_service.dart';
import 'services/vocabulary_service.dart';
import 'models/prediction_result.dart';
import '../../core/utils/debouncer.dart';

class PredictionState {
  final List<PredictionResult> predictions;
  final bool isLoading;
  final String currentContext;
  
  const PredictionState({
    this.predictions = const [],
    this.isLoading = false,
    this.currentContext = '',
  });
  
  PredictionState copyWith({
    List<PredictionResult>? predictions,
    bool? isLoading,
    String? currentContext,
  }) => PredictionState(
    predictions: predictions ?? this.predictions,
    isLoading: isLoading ?? this.isLoading,
    currentContext: currentContext ?? this.currentContext,
  );
}

class PredictionController extends StateNotifier<PredictionState> {
  final ClaudePredictionService _claudeService;
  final NgramService _ngramService;
  final VocabularyService _vocabularyService;
  
  // Debounce — don't fire Claude on every single keypress
  final Debouncer _debouncer = Debouncer(delay: const Duration(milliseconds: 300));
  
  bool _isOnline = true; // Monitored by ConnectivityPlus
  List<String> _recentMessages = [];
  
  PredictionController({
    required ClaudePredictionService claudeService,
    required NgramService ngramService,
    required VocabularyService vocabularyService,
  }) : _claudeService = claudeService,
       _ngramService = ngramService,
       _vocabularyService = vocabularyService,
       super(const PredictionState()) {
    _ngramService.initialize();
  }
  
  void onTextChanged(String text) {
    if (text.trim().length < 2) {
      state = state.copyWith(predictions: [], isLoading: false);
      return;
    }
    
    // Show loading immediately
    state = state.copyWith(isLoading: true);
    
    // Debounce actual API call
    _debouncer.run(() => _fetchPredictions(text));
  }
  
  Future<void> _fetchPredictions(String text) async {
    if (_isOnline) {
      // Try Claude first
      final systemPrompt = _buildSystemPrompt();
      final claudePredictions = await _claudeService.predict(
        currentText: text,
        systemPrompt: systemPrompt,
      );
      
      if (claudePredictions.isNotEmpty) {
        state = state.copyWith(
          predictions: claudePredictions,
          isLoading: false,
        );
        return;
      }
    }
    
    // Fallback: n-gram model (offline, instant)
    final ngramPredictions = _ngramService.predict(text);
    state = state.copyWith(
      predictions: ngramPredictions,
      isLoading: false,
    );
  }
  
  String _buildSystemPrompt() {
    final vocab = _vocabularyService.getTopVocabulary(limit: 50);
    
    return '''
You are the predictive text engine for an AAC communication device.
The user types with their eyes, which is very slow — each letter takes effort.
Your job: predict complete sentences they want to say.

Personal vocabulary they use often: ${vocab.map((v) => v.word).join(', ')}

Recent messages they sent:
${_recentMessages.take(5).map((m) => '- "$m"').join('\n')}

Return ONLY valid JSON: {"predictions": ["prediction1", "prediction2", "prediction3"]}
Each prediction must be a complete, natural English sentence.
Each prediction must start with the exact letters already typed.
Keep predictions under 15 words.
''';
  }
  
  void updateContext(String completedMessage) {
    _recentMessages.insert(0, completedMessage);
    if (_recentMessages.length > 10) _recentMessages.removeLast();
    
    // Learn vocabulary
    _vocabularyService.learnFromMessage(completedMessage);
    _ngramService.learnFromMessage(completedMessage);
    
    // Reset predictions
    state = state.copyWith(predictions: [], currentContext: '');
  }
  
  void setOnlineStatus(bool isOnline) {
    _isOnline = isOnline;
  }
}

final predictionControllerProvider = 
    StateNotifierProvider<PredictionController, PredictionState>(
  (ref) => PredictionController(
    claudeService: ClaudePredictionService()..initialize(),
    ngramService: NgramService(),
    vocabularyService: VocabularyService(Hive.box('vocabulary')),
  ),
);
```

---

## ✅ Milestone: Claude Predictions Working

- [ ] After typing 2+ letters, prediction cards appear within 1.5 seconds
- [ ] Predictions are contextually relevant to what was typed
- [ ] Selecting a prediction fills the message bar with full sentence
- [ ] When offline (disable wifi), n-gram predictions still appear
- [ ] Personal vocabulary updates after each sent message
- [ ] Predictions get better after several uses

---

## 🤖 AI IDE Prompt — Claude AI Integration

```
Build the complete Claude AI prediction system for ECHO.

1. Create ClaudePredictionService that:
   - Calls Anthropic API at https://api.anthropic.com/v1/messages
   - Uses claude-sonnet-4-6 model (fast, efficient)
   - Sends dynamic system prompt with personal vocab and recent messages
   - Expects JSON response: {"predictions": [...]}
   - Has 5-second strict timeout (never block typing)
   - Returns empty list on any error (silent fallback)
   - Parses and validates predictions start with the typed prefix

2. Create NgramService as offline fallback:
   - In-memory trigram model (word1 word2 -> word3 frequency)
   - Loads from assets/ngrams/english_trigrams.json
   - Falls back to minimal hardcoded model if file not found
   - learnFromMessage() updates frequencies from user messages
   - Returns PredictionResult list with confidence scores

3. Create VocabularyService that:
   - Stores word frequency in Hive box
   - learnFromMessage() extracts all words and updates counts
   - getTopVocabulary() returns most-used words sorted by frequency
   - Infers context tags (medical, emotional, family) from word

4. Create PredictionController (Riverpod StateNotifier) that:
   - Debounces text changes by 300ms before calling Claude
   - Shows loading state immediately on text change
   - Tries Claude first, falls back to n-gram if offline or error
   - updateContext() called after each sent message (learns from it)
   - Monitors connectivity to determine online/offline mode

5. Create PredictionCardsWidget showing 3 prediction cards:
   - Each card is a gaze zone (registered with GazeEngine)
   - Dwell fill animation like keyboard keys
   - Selecting fills KeyboardController with full prediction
   - Animated slide-in when new predictions arrive
   - Shimmer loading state

All API keys loaded from dotenv, never hardcoded.
```

---

*Next: `08_VOICE_ENGINE.md` →*
