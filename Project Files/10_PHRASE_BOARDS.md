# 10 — Phrase Boards
## ECHO AAC | Contextual Quick-Access Communication Panels

---

## What We're Building

Phrase boards are pre-built message panels that appear contextually. Instead of spelling letter-by-letter, the patient can gaze at a phrase and speak it instantly. A morning routine board automatically appears at 7am. A medical board appears when a doctor's appointment is scheduled.

This is the second most important feature after the keyboard. Many patients use phrase boards 80% of the time.

---

## Default Phrase Boards (from assets/phrase_boards/default_boards.json)

```json
{
  "boards": [
    {
      "id": "morning_routine",
      "name": "Morning",
      "contextTrigger": "morning",
      "triggerTimeStart": "05:00",
      "triggerTimeEnd": "10:00",
      "icon": "wb_sunny",
      "items": [
        {"text": "Good morning", "icon": "sentiment_satisfied"},
        {"text": "I slept well", "icon": "hotel"},
        {"text": "I did not sleep well", "icon": "hotel"},
        {"text": "I need breakfast", "icon": "restaurant"},
        {"text": "I need my medication", "icon": "medication"},
        {"text": "Please help me get up", "icon": "accessibility"},
        {"text": "I need to use the bathroom", "icon": "wc"},
        {"text": "I am comfortable", "icon": "check_circle"},
        {"text": "Please open the curtains", "icon": "light_mode"}
      ]
    },
    {
      "id": "medical",
      "name": "Medical",
      "contextTrigger": "medical",
      "icon": "medical_services",
      "items": [
        {"text": "I am in pain", "icon": "warning"},
        {"text": "My pain level is 8 out of 10", "icon": "warning"},
        {"text": "The pain is in my chest", "icon": "favorite"},
        {"text": "I cannot breathe well", "icon": "air"},
        {"text": "Please call the nurse", "icon": "call"},
        {"text": "Please call the doctor", "icon": "local_hospital"},
        {"text": "I need more pain medication", "icon": "medication"},
        {"text": "I feel nauseous", "icon": "sick"},
        {"text": "I feel better than yesterday", "icon": "trending_up"}
      ]
    },
    {
      "id": "emotional",
      "name": "Feelings",
      "contextTrigger": "always",
      "icon": "favorite",
      "items": [
        {"text": "I love you", "icon": "favorite"},
        {"text": "Thank you for everything", "icon": "gratitude"},
        {"text": "I am happy today", "icon": "sentiment_very_satisfied"},
        {"text": "I am worried", "icon": "sentiment_dissatisfied"},
        {"text": "I miss you", "icon": "person"},
        {"text": "I am proud of you", "icon": "star"},
        {"text": "I need you here with me", "icon": "people"},
        {"text": "Tell me about your day", "icon": "chat"}
      ]
    },
    {
      "id": "immediate_needs",
      "name": "Needs",
      "contextTrigger": "always",
      "icon": "priority_high",
      "items": [
        {"text": "I need water", "icon": "water_drop"},
        {"text": "I am too hot", "icon": "thermostat"},
        {"text": "I am too cold", "icon": "ac_unit"},
        {"text": "Please adjust my position", "icon": "accessibility_new"},
        {"text": "Please turn on the TV", "icon": "tv"},
        {"text": "Please turn off the lights", "icon": "light"},
        {"text": "I want to listen to music", "icon": "music_note"},
        {"text": "I need quiet please", "icon": "volume_off"}
      ]
    }
  ]
}
```

---

## PhraseContextService

```dart
// lib/features/phrases/services/phrase_context_service.dart

class PhraseContextService {
  String getCurrentContext() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 10) return 'morning';
    if (hour >= 10 && hour < 12) return 'late_morning';
    if (hour >= 12 && hour < 14) return 'lunch';
    if (hour >= 14 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 21) return 'evening';
    return 'night';
  }

  List<PhraseBoard> getSuggestedBoards(
    String context,
    List<PhraseBoard> allBoards,
  ) {
    // Always-visible boards first
    final always = allBoards.where((b) => b.contextTrigger == 'always').toList();
    // Context-matched boards
    final contextual = allBoards.where((b) => b.contextTrigger == context).toList();
    
    return [...contextual, ...always];
  }
  
  Future<List<PhraseBoard>> loadDefaultBoards() async {
    final json = await rootBundle.loadString('assets/phrase_boards/default_boards.json');
    final data = jsonDecode(json);
    return (data['boards'] as List).map((b) => PhraseBoard.fromJson(b)).toList();
  }
}
```

---

## PhraseBoardsScreen UI

```dart
// Two-column grid of board cards
// Each card shows: icon, name, item count
// Tapping (or dwelling) on board → navigate to board items
// Board items shown as 2-column grid of large buttons

class PhraseBoardsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Phrase Boards'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        // ... board cards
      ),
    );
  }
}

// Phrase item button — gaze-selectable, min 80x80px
// On selection: VoiceController.speak(item.text)
// Also adds to message bar so patient can modify before speaking
```

---

## 🤖 AI IDE Prompt — Phrase Boards

```
Build the phrase boards system for ECHO.

1. Create PhraseBoard and PhraseItem Freezed models
2. Create default_boards.json asset with 4 boards (morning, medical, 
   emotional, immediate_needs) each with 8-9 phrases
3. PhraseContextService: getCurrentContext() based on time of day,
   getSuggestedBoards() returns contextual + always-visible boards
4. PhraseBoardsScreen: 2-column grid of board cards (icon + name + count)
5. PhraseItemsView: 2-column grid of large buttons (min 80x80px),
   each is a gaze zone, selection speaks the phrase via VoiceController
6. Save user's custom boards to Hive, sync to Supabase
7. Auto-surface relevant board in main screen banner at trigger times
```
