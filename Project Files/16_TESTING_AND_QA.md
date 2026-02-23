# 16 — Testing and QA
## ECHO AAC | Unit, Widget, Integration Testing Protocol

---

## Testing Philosophy

For a medical app, tests are not optional. A bug in ECHO's emergency system could cost a life. A bug in the gaze engine means a patient can't communicate. Every critical path must have a test.

---

## Unit Tests

See PROMPT 15 in `18_AI_IDE_PROMPTS.md` for full test code.

Key test files:
- `gaze_calculator_test.dart` — math accuracy tests
- `blink_detector_test.dart` — timing edge cases
- `calibration_service_test.dart` — accuracy computation
- `ngram_service_test.dart` — offline prediction quality

---

## Widget Tests

```dart
// gaze_keyboard_test.dart
testWidgets('all 26 letters render', (tester) async {
  await tester.pumpWidget(
    ProviderScope(child: MaterialApp(home: Scaffold(body: GazeKeyboard())))
  );
  // Verify all letters A-Z present
  for (final letter in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')) {
    expect(find.text(letter), findsOneWidget);
  }
});

testWidgets('SPEAK button is green', (tester) async {
  // ... verify SPEAK has green color
});
```

---

## Real Device Testing Protocol

This cannot be automated. Required before any release:

1. **Gaze Tracking Test** — 3 different lighting conditions (bright, dim, backlit)
2. **Calibration Test** — accuracy score must exceed 90% for 3 different users
3. **Emergency Test** — double blink → SMS received on test phone within 3 seconds
4. **Offline Test** — disable WiFi → all core features still work
5. **Long Session Test** — 2-hour continuous use → no memory leaks, no drift in gaze accuracy
6. **Different Device Test** — test on Android and iOS, minimum 2 different screen sizes

---

## Performance Profiling

```bash
# Profile mode build (shows performance overlay)
flutter run --profile

# In DevTools → CPU profiler → check gaze processing time
# Target: < 16ms per frame (60fps)
# If >16ms: check which service is the bottleneck
# Common bottleneck: MediaPipe processing on main thread
# Fix: move to isolate (see gaze_engine_controller.dart comments)
```

---

## 🤖 AI IDE Prompt — Tests

See PROMPT 15 in `18_AI_IDE_PROMPTS.md`.
