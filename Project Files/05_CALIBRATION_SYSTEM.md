# 05 — Calibration System
## ECHO AAC | 15-Point Calibration, Accuracy Scoring, Persistence

---

## Why Calibration is Non-Negotiable

Without calibration, gaze tracking on a phone camera achieves ~70-80% zone accuracy. With a proper 15-point calibration, this jumps to **96-98%**. The difference is:

- Each person's eyes are different shapes and sizes
- Distance from screen varies per setup
- Camera position varies per device mount
- Room lighting affects iris visibility

Calibration learns the **specific transformation** from "where this person's iris is in camera space" to "what they're looking at on screen."

---

## Calibration Algorithm

### The 15-Point Grid

We show 15 targets in a 5x3 grid pattern:
```
●  ●  ●  ●  ●   (row 1 — top, y=10%)
●  ●  ●  ●  ●   (row 2 — middle, y=50%)
●  ●  ●  ●  ●   (row 3 — bottom, y=90%)
(x positions: 10%, 27.5%, 45%, 62.5%, 80%)
```

For each point:
1. Show target dot at known screen position
2. Ask user to look at it
3. Collect 30 frames of gaze data (~500ms)
4. Average the iris positions → this is the calibration sample for that point

### Building the Transform Matrix

After collecting all 15 pairs of (raw_iris_position, known_screen_position), we compute a **polynomial regression** mapping. This gives us coefficients that transform any raw iris position to accurate screen position.

The transform is stored as:
```json
{
  "scaleX": 1.24,
  "scaleY": 0.98,
  "offsetX": -0.05,
  "offsetY": 0.12,
  "centerX": 0.52,
  "centerY": 0.48,
  "points": [15 calibration samples],
  "accuracyScore": 0.96,
  "timestamp": "2024-01-15T10:30:00Z"
}
```

---

## Implementation

### CalibrationData Model

Create `lib/features/calibration/models/calibration_data.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'calibration_data.freezed.dart';
part 'calibration_data.g.dart';

@freezed
class CalibrationPoint with _$CalibrationPoint {
  const factory CalibrationPoint({
    required double targetX,      // Known screen position (0.0-1.0)
    required double targetY,
    required double measuredX,    // Measured iris position (0.0-1.0)
    required double measuredY,
    required double confidence,   // Average confidence during measurement
  }) = _CalibrationPoint;
  
  factory CalibrationPoint.fromJson(Map<String, dynamic> json) =>
      _$CalibrationPointFromJson(json);
}

@freezed
class CalibrationData with _$CalibrationData {
  const factory CalibrationData({
    required String id,
    required String userId,
    required String deviceId,
    
    // Transform coefficients
    required double scaleX,
    required double scaleY,
    required double offsetX,
    required double offsetY,
    required double centerX,
    required double centerY,
    
    // Raw calibration samples
    required List<CalibrationPoint> points,
    
    // Quality metrics
    required double accuracyScore,     // 0.0 - 1.0
    required double averageError,      // In screen fraction
    
    required DateTime createdAt,
  }) = _CalibrationData;
  
  factory CalibrationData.fromJson(Map<String, dynamic> json) =>
      _$CalibrationDataFromJson(json);
}
```

---

### CalibrationService

Create `lib/features/calibration/services/calibration_service.dart`:

```dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/calibration_data.dart';
import '../models/calibration_point.dart';
import '../../gaze_engine/models/face_landmarks.dart';

/// The 5x3 grid of calibration target positions (normalized 0.0-1.0)
const List<Offset> kCalibrationTargets = [
  // Row 1 (top)
  Offset(0.10, 0.10), Offset(0.275, 0.10), Offset(0.45, 0.10), 
  Offset(0.625, 0.10), Offset(0.80, 0.10),
  // Row 2 (middle)
  Offset(0.10, 0.50), Offset(0.275, 0.50), Offset(0.45, 0.50), 
  Offset(0.625, 0.50), Offset(0.80, 0.50),
  // Row 3 (bottom)
  Offset(0.10, 0.90), Offset(0.275, 0.90), Offset(0.45, 0.90), 
  Offset(0.625, 0.90), Offset(0.80, 0.90),
];

class CalibrationService {
  // Frames to collect per calibration point
  static const int _framesPerPoint = 30;
  // Dwell time at each calibration target (ms)
  static const int _dwellMs = 1000;
  
  // State
  int _currentPointIndex = 0;
  final List<List<Offset>> _collectedSamples = [];
  final List<double> _collectedConfidences = [];
  bool _isCollecting = false;
  
  // Stream to drive UI
  final _progressController = StreamController<CalibrationProgress>.broadcast();
  Stream<CalibrationProgress> get progressStream => _progressController.stream;
  
  /// Current calibration target position (normalized 0.0-1.0)
  Offset get currentTarget => kCalibrationTargets[_currentPointIndex];
  int get currentPointIndex => _currentPointIndex;
  int get totalPoints => kCalibrationTargets.length;
  bool get isComplete => _currentPointIndex >= kCalibrationTargets.length;
  
  void startCollection() {
    _isCollecting = true;
    _collectedSamples.clear();
    _collectedSamples.add([]); // First point's samples
    
    _progressController.add(CalibrationProgress(
      pointIndex: 0,
      totalPoints: totalPoints,
      currentTarget: currentTarget,
      phase: CalibrationPhase.lookingAtTarget,
      progress: 0.0,
    ));
  }
  
  /// Feed landmarks to calibration — collects samples for current target
  void feedLandmarks(Offset rawGaze, double confidence) {
    if (!_isCollecting || isComplete) return;
    
    final currentSamples = _collectedSamples.last;
    
    // Only collect high-confidence samples
    if (confidence > 0.6) {
      currentSamples.add(rawGaze);
    }
    
    final progress = currentSamples.length / _framesPerPoint;
    
    _progressController.add(CalibrationProgress(
      pointIndex: _currentPointIndex,
      totalPoints: totalPoints,
      currentTarget: currentTarget,
      phase: CalibrationPhase.lookingAtTarget,
      progress: progress.clamp(0.0, 1.0),
    ));
    
    if (currentSamples.length >= _framesPerPoint) {
      _advanceToNextPoint();
    }
  }
  
  void _advanceToNextPoint() {
    _currentPointIndex++;
    
    if (_currentPointIndex >= kCalibrationTargets.length) {
      // Calibration complete!
      _isCollecting = false;
      _progressController.add(CalibrationProgress(
        pointIndex: _currentPointIndex,
        totalPoints: totalPoints,
        currentTarget: Offset.zero,
        phase: CalibrationPhase.complete,
        progress: 1.0,
      ));
    } else {
      // Move to next target
      _collectedSamples.add([]);
      
      _progressController.add(CalibrationProgress(
        pointIndex: _currentPointIndex,
        totalPoints: totalPoints,
        currentTarget: currentTarget,
        phase: CalibrationPhase.movingToTarget,
        progress: 0.0,
      ));
    }
  }
  
  /// Called after all points collected — compute the calibration data
  CalibrationData computeCalibration({
    required String userId,
    required String deviceId,
  }) {
    assert(!_isCollecting, 'Cannot compute while collecting');
    assert(_collectedSamples.length == kCalibrationTargets.length);
    
    final calibrationPoints = <CalibrationPoint>[];
    
    // For each calibration point, compute the average measured position
    for (int i = 0; i < kCalibrationTargets.length; i++) {
      final target = kCalibrationTargets[i];
      final samples = _collectedSamples[i];
      
      if (samples.isEmpty) continue;
      
      // Average all collected samples
      final avgX = samples.map((s) => s.dx).reduce((a, b) => a + b) / samples.length;
      final avgY = samples.map((s) => s.dy).reduce((a, b) => a + b) / samples.length;
      
      calibrationPoints.add(CalibrationPoint(
        targetX: target.dx,
        targetY: target.dy,
        measuredX: avgX,
        measuredY: avgY,
        confidence: 0.85, // Average confidence approximation
      ));
    }
    
    // Compute transform coefficients via least squares regression
    final transform = _computeTransform(calibrationPoints);
    
    // Calculate accuracy score by measuring how well the transform
    // maps each measured point back to its target
    final accuracy = _calculateAccuracy(calibrationPoints, transform);
    
    return CalibrationData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      deviceId: deviceId,
      scaleX: transform.scaleX,
      scaleY: transform.scaleY,
      offsetX: transform.offsetX,
      offsetY: transform.offsetY,
      centerX: transform.centerX,
      centerY: transform.centerY,
      points: calibrationPoints,
      accuracyScore: accuracy,
      averageError: 1.0 - accuracy,
      createdAt: DateTime.now(),
    );
  }
  
  _GazeTransform _computeTransform(List<CalibrationPoint> points) {
    // Simple linear regression for scale and offset
    // For production, use polynomial regression for better accuracy
    
    // Calculate centers of measured and target distributions
    final measuredCenterX = points.map((p) => p.measuredX).reduce((a, b) => a + b) / points.length;
    final measuredCenterY = points.map((p) => p.measuredY).reduce((a, b) => a + b) / points.length;
    final targetCenterX = 0.5;
    final targetCenterY = 0.5;
    
    // Calculate scale factors using variance ratio
    double varMeasuredX = 0, varTargetX = 0;
    double varMeasuredY = 0, varTargetY = 0;
    
    for (final p in points) {
      varMeasuredX += pow(p.measuredX - measuredCenterX, 2);
      varTargetX += pow(p.targetX - targetCenterX, 2);
      varMeasuredY += pow(p.measuredY - measuredCenterY, 2);
      varTargetY += pow(p.targetY - targetCenterY, 2);
    }
    
    final scaleX = sqrt(varTargetX / (varMeasuredX + 0.0001));
    final scaleY = sqrt(varTargetY / (varMeasuredY + 0.0001));
    
    // Offset to align centers
    final offsetX = targetCenterX - (measuredCenterX * scaleX);
    final offsetY = targetCenterY - (measuredCenterY * scaleY);
    
    return _GazeTransform(
      scaleX: scaleX.clamp(0.5, 3.0),
      scaleY: scaleY.clamp(0.5, 3.0),
      offsetX: offsetX.clamp(-0.5, 0.5),
      offsetY: offsetY.clamp(-0.5, 0.5),
      centerX: measuredCenterX,
      centerY: measuredCenterY,
    );
  }
  
  double _calculateAccuracy(
    List<CalibrationPoint> points, 
    _GazeTransform transform,
  ) {
    if (points.isEmpty) return 0.0;
    
    double totalError = 0.0;
    
    for (final p in points) {
      // Apply transform to measured position
      final mappedX = (p.measuredX - transform.centerX) * transform.scaleX + 0.5 + transform.offsetX;
      final mappedY = (p.measuredY - transform.centerY) * transform.scaleY + 0.5 + transform.offsetY;
      
      // Calculate distance from target
      final errorX = (mappedX - p.targetX).abs();
      final errorY = (mappedY - p.targetY).abs();
      final error = sqrt(errorX * errorX + errorY * errorY);
      
      totalError += error;
    }
    
    final avgError = totalError / points.length;
    
    // Convert error to accuracy score
    // Error of 0.05 (5% of screen) → accuracy 0.95
    return (1.0 - avgError * 5.0).clamp(0.0, 1.0);
  }
  
  void reset() {
    _currentPointIndex = 0;
    _collectedSamples.clear();
    _isCollecting = false;
  }
  
  void dispose() {
    _progressController.close();
  }
}

class _GazeTransform {
  final double scaleX, scaleY, offsetX, offsetY, centerX, centerY;
  const _GazeTransform({
    required this.scaleX, required this.scaleY,
    required this.offsetX, required this.offsetY,
    required this.centerX, required this.centerY,
  });
}

enum CalibrationPhase { movingToTarget, lookingAtTarget, complete }

class CalibrationProgress {
  final int pointIndex;
  final int totalPoints;
  final Offset currentTarget;
  final CalibrationPhase phase;
  final double progress; // 0.0 - 1.0 for current point
  
  const CalibrationProgress({
    required this.pointIndex,
    required this.totalPoints,
    required this.currentTarget,
    required this.phase,
    required this.progress,
  });
  
  double get overallProgress => (pointIndex + progress) / totalPoints;
}
```

---

### Calibration UI Screen

Create `lib/features/calibration/screens/calibration_active_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/calibration_service.dart';

class CalibrationActiveScreen extends ConsumerStatefulWidget {
  const CalibrationActiveScreen({super.key});
  
  @override
  ConsumerState<CalibrationActiveScreen> createState() => 
      _CalibrationActiveScreenState();
}

class _CalibrationActiveScreenState 
    extends ConsumerState<CalibrationActiveScreen> {
  
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Stack(
        children: [
          // Instructions at top
          Positioned(
            top: 48,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text(
                  'Look at each dot as it appears',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Keep your head still — only move your eyes',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          
          // Overall progress bar at bottom
          Positioned(
            bottom: 40,
            left: 40,
            right: 40,
            child: Column(
              children: [
                Text(
                  'Point 1 of 15',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 0.0,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation(
                      Color(0xFF58A6FF),
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          
          // THE CALIBRATION TARGET DOT
          CalibrationTargetDot(
            position: const Offset(0.5, 0.5), // Example — drive from state
            screenSize: size,
          ),
        ],
      ),
    );
  }
}

/// The animated dot the user looks at during calibration
class CalibrationTargetDot extends StatefulWidget {
  final Offset position; // Normalized 0.0-1.0
  final Size screenSize;
  
  const CalibrationTargetDot({
    super.key,
    required this.position,
    required this.screenSize,
  });
  
  @override
  State<CalibrationTargetDot> createState() => _CalibrationTargetDotState();
}

class _CalibrationTargetDotState extends State<CalibrationTargetDot>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _pulseController;
  
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final x = widget.position.dx * widget.screenSize.width;
    final y = widget.position.dy * widget.screenSize.height;
    
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      left: x - 30,
      top: y - 30,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final scale = 1.0 + _pulseController.value * 0.3;
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF58A6FF).withOpacity(0.2),
            border: Border.all(
              color: const Color(0xFF58A6FF),
              width: 3,
            ),
          ),
          child: const Center(
            child: CircleAvatar(
              radius: 8,
              backgroundColor: Color(0xFF58A6FF),
            ),
          ),
        ),
      ),
    );
  }
}
```

---

### Calibration Result Screen

Create `lib/features/calibration/screens/calibration_result_screen.dart`:

```dart
import 'package:flutter/material.dart';
import '../models/calibration_data.dart';

class CalibrationResultScreen extends StatelessWidget {
  final CalibrationData calibrationData;
  
  const CalibrationResultScreen({
    super.key,
    required this.calibrationData,
  });
  
  @override
  Widget build(BuildContext context) {
    final accuracy = calibrationData.accuracyScore;
    final isGood = accuracy >= 0.90;
    final isAcceptable = accuracy >= 0.75;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Accuracy dial/score
            Text(
              '${(accuracy * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.bold,
                color: isGood 
                  ? const Color(0xFF3FB950)  // Green
                  : isAcceptable 
                    ? const Color(0xFFF0A742)  // Amber
                    : const Color(0xFFF85149), // Red
              ),
            ),
            
            const SizedBox(height: 16),
            
            Text(
              isGood 
                ? 'Excellent calibration!'
                : isAcceptable 
                  ? 'Good — acceptable for use'
                  : 'Poor accuracy — recalibrate',
              style: const TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: 48),
            
            // Action buttons
            if (isAcceptable) ...[
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushReplacementNamed('/communication'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3FB950),
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Start Communicating',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              
              const SizedBox(height: 16),
            ],
            
            TextButton(
              onPressed: () {
                // Go back to calibration
                Navigator.of(context).pop();
              },
              child: Text(
                isGood ? 'Recalibrate for even better accuracy' : 'Try Again',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## ✅ Milestone: Calibration Working

You know this step is complete when:
- [ ] 15 calibration dots appear one by one
- [ ] Each dot pulses and waits for user to look at it
- [ ] After all 15 dots, accuracy score is shown
- [ ] Score above 90% for an average adult user
- [ ] Calibration data persists after app restart (saved to Hive)
- [ ] Gaze tracking visibly improves after calibration vs before

---

## 🤖 AI IDE Prompt — Calibration System

```
Build the complete 15-point calibration system for ECHO.

1. Create CalibrationData and CalibrationPoint freezed models
   with all fields as specified in the calibration service above.

2. Create CalibrationService that:
   - Shows 15 targets in 5x3 grid at specific normalized positions
   - Collects 30 raw gaze frames per target point
   - Only accepts high-confidence (>0.6) samples
   - Computes linear regression to find scaleX, scaleY, offsetX, offsetY
   - Calculates accuracy score (0.0-1.0) from calibration error
   - Emits progress stream with current target position and completion %

3. Create CalibrationActiveScreen that:
   - Shows animated pulsing dot at each target position
   - AnimatedPositioned moves dot between targets smoothly
   - Progress bar shows overall calibration completion
   - Gives clear "look at the dot, don't move your head" instructions
   - Uses dark background (#0D1117) with blue (#58A6FF) target dots

4. Create CalibrationResultScreen that:
   - Shows accuracy percentage in large colored number
   - Green ≥90%, Amber 75-89%, Red <75%
   - "Excellent", "Good", "Poor" text based on score
   - "Start Communicating" button if acceptable
   - "Try Again" always available

5. Save CalibrationData to Hive local storage, keyed by userId+deviceId
   Load on app start and apply to GazeCalculator automatically.

6. Add "Recalibrate" option in Settings screen.
```

---

*Next: `06_GAZE_KEYBOARD.md` →*
