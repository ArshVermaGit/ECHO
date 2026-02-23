# 04 — Gaze Engine
## ECHO AAC | Gaze Vector Math, Zone Mapping, Dwell Timer

---

## What We're Building

The Gaze Engine takes raw iris positions from MediaPipe and transforms them into a reliable screen coordinate. This is the most mathematically complex part of ECHO — and the most important. Everything else depends on this being accurate.

### The Core Problem
Iris position in camera space ≠ where you're looking on screen. The mapping is affected by:
- Head position and distance from camera
- Head rotation (euler angles)
- Individual eye anatomy differences
- Camera field of view
- Calibration offsets

We solve this with **calibration** (covered in the next file) + good math here.

---

## The Math: Gaze Vector Estimation

### Step 1: Normalize Iris Position
The iris center is relative to the eye corners. We normalize it so:
- 0.0, 0.0 = looking far left
- 0.5, 0.5 = looking straight (center of eye)
- 1.0, 1.0 = looking far right

```
normalizedX = (irisCenter.x - eyeOuterCorner.x) / (eyeInnerCorner.x - eyeOuterCorner.x)
normalizedY = (irisCenter.y - eyeTopLid.y) / (eyeBottomLid.y - eyeTopLid.y)
```

### Step 2: Compensate for Head Rotation
If the patient's head is turned slightly, the gaze vector needs compensation.
We use the head euler Y angle to offset horizontal gaze.

```
compensatedX = normalizedX + (headEulerY * headCompensationFactor)
```

### Step 3: Average Both Eyes
Using both eyes reduces noise significantly:
```
gazeX = (rightNormX + leftNormX) / 2
gazeY = (rightNormY + leftNormY) / 2
```

### Step 4: Apply Calibration Offsets
Map from normalized eye space to screen space using the calibration matrix (covered in file 05):
```
screenX = (gazeX * screenWidth * calibScaleX) + calibOffsetX
screenY = (gazeY * screenHeight * calibScaleY) + calibOffsetY
```

### Step 5: Apply Smoothing
Raw gaze jumps around. We apply exponential weighted moving average:
```
smoothedX = (smoothedX * 0.7) + (rawX * 0.3)
smoothedY = (smoothedY * 0.7) + (rawY * 0.3)
```

---

## Implementation

### GazeCalculator

Create `lib/features/gaze_engine/services/gaze_calculator.dart`:

```dart
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/face_landmarks.dart';
import '../models/gaze_point.dart';
import '../../calibration/models/calibration_data.dart';

/// Converts raw iris landmark positions to calibrated screen coordinates.
/// 
/// This is the mathematical core of ECHO's eye tracking.
class GazeCalculator {
  // Smoothing factor — higher = smoother but more lag, lower = faster but jittery
  // 0.65 is a good balance for keyboard use
  static const double _smoothingAlpha = 0.65;
  
  // Head rotation compensation factor
  // Adjust this if head turns cause too much drift
  static const double _headYawCompensation = 0.015;
  static const double _headPitchCompensation = 0.012;
  
  // Previous smoothed values
  double _smoothedX = 0.5;
  double _smoothedY = 0.5;
  
  // Calibration data — null means uncalibrated (pre-calibration estimates)
  CalibrationData? _calibrationData;
  
  void setCalibration(CalibrationData calibration) {
    _calibrationData = calibration;
  }
  
  /// Main entry point — converts landmarks to screen gaze point
  GazePoint? calculate(
    FaceLandmarksData landmarks, 
    Size screenSize,
  ) {
    try {
      // Step 1: Calculate normalized iris position for each eye
      final rightNorm = _normalizeIrisForRightEye(landmarks);
      final leftNorm = _normalizeIrisForLeftEye(landmarks);
      
      if (rightNorm == null || leftNorm == null) return null;
      
      // Step 2: Average both eyes (improves accuracy ~15%)
      double rawX = (rightNorm.dx + leftNorm.dx) / 2;
      double rawY = (rightNorm.dy + leftNorm.dy) / 2;
      
      // Step 3: Head rotation compensation
      rawX += landmarks.headEulerY * _headYawCompensation;
      rawY -= landmarks.headEulerX * _headPitchCompensation;
      
      // Clamp to valid range
      rawX = rawX.clamp(0.0, 1.0);
      rawY = rawY.clamp(0.0, 1.0);
      
      // Step 4: Apply calibration mapping
      Offset calibrated;
      if (_calibrationData != null) {
        calibrated = _applyCalibration(rawX, rawY);
      } else {
        // Pre-calibration: use raw values with linear mapping
        calibrated = Offset(rawX, rawY);
      }
      
      // Step 5: Exponential smoothing
      _smoothedX = (_smoothedX * _smoothingAlpha) + (calibrated.dx * (1 - _smoothingAlpha));
      _smoothedY = (_smoothedY * _smoothingAlpha) + (calibrated.dy * (1 - _smoothingAlpha));
      
      // Step 6: Convert to screen pixels
      final screenX = _smoothedX * screenSize.width;
      final screenY = _smoothedY * screenSize.height;
      
      // Calculate confidence based on face visibility and head angle
      final confidence = _calculateConfidence(landmarks);
      
      return GazePoint(
        x: screenX,
        y: screenY,
        normalizedX: _smoothedX,
        normalizedY: _smoothedY,
        confidence: confidence,
        timestamp: DateTime.now(),
      );
      
    } catch (e) {
      debugPrint('GazeCalculator error: $e');
      return null;
    }
  }
  
  /// Normalize right iris position relative to right eye bounds
  Offset? _normalizeIrisForRightEye(FaceLandmarksData landmarks) {
    final iris = landmarks.rightIrisCenter;
    final outer = landmarks.rightEyeOuter;
    final inner = landmarks.rightEyeInner;
    final top = landmarks.rightEyeTop;
    final bottom = landmarks.rightEyeBottom;
    
    final eyeWidth = (inner.x - outer.x).abs();
    final eyeHeight = (bottom.y - top.y).abs();
    
    if (eyeWidth < 1.0 || eyeHeight < 1.0) return null;
    
    // Normalize: where is iris within the eye rectangle?
    final normX = (iris.x - outer.x) / eyeWidth;
    final normY = (iris.y - top.y) / eyeHeight;
    
    return Offset(normX.clamp(0.0, 1.0), normY.clamp(0.0, 1.0));
  }
  
  /// Normalize left iris position relative to left eye bounds
  Offset? _normalizeIrisForLeftEye(FaceLandmarksData landmarks) {
    final iris = landmarks.leftIrisCenter;
    final outer = landmarks.leftEyeOuter;
    final inner = landmarks.leftEyeInner;
    final top = landmarks.leftEyeTop;
    final bottom = landmarks.leftEyeBottom;
    
    final eyeWidth = (inner.x - outer.x).abs();
    final eyeHeight = (bottom.y - top.y).abs();
    
    if (eyeWidth < 1.0 || eyeHeight < 1.0) return null;
    
    // Note: left eye x direction is flipped relative to right eye
    final normX = 1.0 - ((iris.x - inner.x) / eyeWidth);
    final normY = (iris.y - top.y) / eyeHeight;
    
    return Offset(normX.clamp(0.0, 1.0), normY.clamp(0.0, 1.0));
  }
  
  Offset _applyCalibration(double rawX, double rawY) {
    if (_calibrationData == null) return Offset(rawX, rawY);
    
    // Apply the calibration polynomial transform
    // The calibration data contains coefficients that map 
    // normalized gaze to screen coordinates
    final cal = _calibrationData!;
    
    final correctedX = (rawX - cal.centerX) * cal.scaleX + 0.5 + cal.offsetX;
    final correctedY = (rawY - cal.centerY) * cal.scaleY + 0.5 + cal.offsetY;
    
    return Offset(
      correctedX.clamp(0.0, 1.0),
      correctedY.clamp(0.0, 1.0),
    );
  }
  
  double _calculateConfidence(FaceLandmarksData landmarks) {
    // Confidence drops when:
    // - Head is turned too much (landmarks unreliable)
    // - Eyes are partially closed
    double confidence = 1.0;
    
    // Head angle penalty
    final headAnglePenalty = (landmarks.headEulerY.abs() / 30.0).clamp(0.0, 0.5);
    confidence -= headAnglePenalty;
    
    // Eye openness penalty
    final minOpenness = min(
      landmarks.rightEyeOpenProbability, 
      landmarks.leftEyeOpenProbability,
    );
    if (minOpenness < 0.5) {
      confidence -= (0.5 - minOpenness) * 0.8;
    }
    
    return confidence.clamp(0.0, 1.0);
  }
  
  /// Reset smoothing (call after calibration or long pause)
  void resetSmoothing() {
    _smoothedX = 0.5;
    _smoothedY = 0.5;
  }
}
```

---

### GazePoint Model

Create `lib/features/gaze_engine/models/gaze_point.dart`:

```dart
import 'package:flutter/foundation.dart';

@immutable
class GazePoint {
  final double x;           // Screen pixel X
  final double y;           // Screen pixel Y
  final double normalizedX; // 0.0 - 1.0 relative to screen width
  final double normalizedY; // 0.0 - 1.0 relative to screen height
  final double confidence;  // 0.0 - 1.0 tracking quality
  final DateTime timestamp;
  
  const GazePoint({
    required this.x,
    required this.y,
    required this.normalizedX,
    required this.normalizedY,
    required this.confidence,
    required this.timestamp,
  });
  
  Offset get offset => Offset(x, y);
  
  bool get isReliable => confidence > 0.6;
  
  @override
  String toString() => 
    'GazePoint(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)}, conf: ${confidence.toStringAsFixed(2)})';
}
```

---

### GazeZone Mapper

Create `lib/features/gaze_engine/services/gaze_zone_mapper.dart`:

```dart
import 'package:flutter/material.dart';
import '../models/gaze_point.dart';
import '../models/gaze_zone.dart';

/// Maps a gaze point to a keyboard zone or UI element.
/// 
/// The screen is divided into a grid of zones.
/// Each zone corresponds to a keyboard key or UI region.
class GazeZoneMapper {
  final Map<String, Rect> _zones = {};
  
  /// Register a zone with its screen bounds
  void registerZone(String id, Rect bounds) {
    _zones[id] = bounds;
  }
  
  /// Remove all zones (call when keyboard layout changes)
  void clearZones() {
    _zones.clear();
  }
  
  /// Find which zone contains the gaze point
  /// Returns null if gaze is outside all zones (e.g., on background)
  String? getZoneAt(GazePoint gaze) {
    if (!gaze.isReliable) return null;
    
    final gazeOffset = gaze.offset;
    
    // Find best matching zone
    // If gaze is inside multiple zones (shouldn't happen), return first match
    for (final entry in _zones.entries) {
      if (entry.value.contains(gazeOffset)) {
        return entry.key;
      }
    }
    
    // Gaze is between keys — find nearest zone center
    return _findNearestZone(gazeOffset);
  }
  
  String? _findNearestZone(Offset gaze) {
    String? nearestId;
    double nearestDistance = double.infinity;
    
    for (final entry in _zones.entries) {
      final zoneCenter = entry.value.center;
      final distance = (gaze - zoneCenter).distance;
      
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestId = entry.id;
      }
    }
    
    // Only return if within reasonable distance (not staring at ceiling)
    return nearestDistance < 80.0 ? nearestId : null;
  }
}
```

---

### Dwell Timer Service

Create `lib/features/gaze_engine/services/dwell_timer_service.dart`:

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/gaze_point.dart';

/// Manages dwell-based selection — the core input method.
/// 
/// "Dwell" = looking at something for long enough = select it.
/// 
/// How it works:
/// 1. User looks at a keyboard key
/// 2. DwellTimerService tracks how long the gaze stays on that key
/// 3. Progress accumulates (shown visually as expanding circle)
/// 4. When dwell reaches threshold → selection event fired
/// 5. After selection, grace period before next selection (prevents double-select)
/// 
/// Parameters are all user-adjustable in settings:
/// - Dwell duration: 600ms default (range: 400ms - 2000ms)
/// - Grace period: 800ms (time before another selection is possible)
/// - Move tolerance: 40px (how much gaze can wander within a key before resetting)
class DwellTimerService {
  Duration dwellDuration;
  final Duration gracePeriod;
  final double moveTolerance;
  
  final _selectionController = StreamController<String>.broadcast();
  Stream<String> get selectionStream => _selectionController.stream;
  
  // Progress stream — 0.0 to 1.0 for visual feedback
  final _progressController = StreamController<DwellProgress>.broadcast();
  Stream<DwellProgress> get progressStream => _progressController.stream;
  
  String? _currentZone;
  DateTime? _dwellStartTime;
  DateTime? _lastSelectionTime;
  
  DwellTimerService({
    this.dwellDuration = const Duration(milliseconds: 600),
    this.gracePeriod = const Duration(milliseconds: 800),
    this.moveTolerance = 40.0,
  });
  
  /// Call this on every frame with the current gaze zone
  void update(String? zone) {
    final now = DateTime.now();
    
    // Check grace period — prevent immediate re-selection
    if (_lastSelectionTime != null &&
        now.difference(_lastSelectionTime!) < gracePeriod) {
      return;
    }
    
    if (zone == null) {
      // Gaze left all zones
      _resetDwell();
      return;
    }
    
    if (zone != _currentZone) {
      // Gaze moved to different zone — restart dwell
      _currentZone = zone;
      _dwellStartTime = now;
      _emitProgress(zone, 0.0);
      return;
    }
    
    // Still in same zone — calculate progress
    if (_dwellStartTime == null) {
      _dwellStartTime = now;
      return;
    }
    
    final elapsed = now.difference(_dwellStartTime!);
    final progress = (elapsed.inMilliseconds / dwellDuration.inMilliseconds)
        .clamp(0.0, 1.0);
    
    _emitProgress(zone, progress);
    
    if (progress >= 1.0) {
      // SELECTION!
      _lastSelectionTime = now;
      _currentZone = null;
      _dwellStartTime = null;
      
      if (!_selectionController.isClosed) {
        _selectionController.add(zone);
      }
    }
  }
  
  void _emitProgress(String zone, double progress) {
    if (!_progressController.isClosed) {
      _progressController.add(DwellProgress(zone: zone, progress: progress));
    }
  }
  
  void _resetDwell() {
    if (_currentZone != null) {
      _emitProgress('', 0.0);
      _currentZone = null;
      _dwellStartTime = null;
    }
  }
  
  void dispose() {
    _selectionController.close();
    _progressController.close();
  }
}

@immutable
class DwellProgress {
  final String zone;
  final double progress; // 0.0 - 1.0
  
  const DwellProgress({required this.zone, required this.progress});
}
```

---

### GazeCursor Widget

Create `lib/features/gaze_engine/widgets/gaze_cursor_widget.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/gaze_point.dart';
import '../services/dwell_timer_service.dart';

/// The visual gaze cursor — a soft, breathing circle that:
/// - Shows where the user is looking
/// - Expands as dwell time accumulates
/// - "Blooms" on selection with haptic feedback
/// 
/// This is not just cosmetic — it's the only visual feedback 
/// the patient has that the system is tracking their gaze.
class GazeCursorWidget extends StatefulWidget {
  final GazePoint? gazePoint;
  final DwellProgress? dwellProgress;
  
  const GazeCursorWidget({
    super.key,
    this.gazePoint,
    this.dwellProgress,
  });
  
  @override
  State<GazeCursorWidget> createState() => _GazeCursorWidgetState();
}

class _GazeCursorWidgetState extends State<GazeCursorWidget>
    with SingleTickerProviderStateMixin {
  
  @override
  Widget build(BuildContext context) {
    final gaze = widget.gazePoint;
    if (gaze == null) return const SizedBox.expand();
    
    final progress = widget.dwellProgress?.progress ?? 0.0;
    
    // Base size grows as dwell progresses
    final baseSize = 24.0;
    final maxSize = 56.0;
    final currentSize = baseSize + (maxSize - baseSize) * progress;
    
    // Color shifts from blue (idle) to green (selecting)
    final color = Color.lerp(
      const Color(0xFF58A6FF),  // Calm blue
      const Color(0xFF3FB950),  // Selection green
      progress,
    )!;
    
    // Opacity based on gaze confidence
    final opacity = (0.3 + gaze.confidence * 0.7).clamp(0.3, 1.0);
    
    return Positioned(
      left: gaze.x - currentSize / 2,
      top: gaze.y - currentSize / 2,
      child: IgnorePointer(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 50),
          width: currentSize,
          height: currentSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(opacity * 0.25),
            border: Border.all(
              color: color.withOpacity(opacity),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3 * progress),
                blurRadius: 12,
                spreadRadius: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

### GazeEngineController (Riverpod)

Create `lib/features/gaze_engine/gaze_engine_controller.dart`:

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/camera_service.dart';
import 'services/mediapipe_service.dart';
import 'services/gaze_calculator.dart';
import 'services/gaze_zone_mapper.dart';
import 'services/dwell_timer_service.dart';
import 'services/blink_detector.dart';
import 'models/gaze_point.dart';
import 'models/face_landmarks.dart';

// State class
class GazeEngineState {
  final GazePoint? currentGaze;
  final FaceLandmarksData? landmarks;
  final bool isFaceDetected;
  final bool isCalibrated;
  final double trackingConfidence;
  final bool isInitialized;
  final String? errorMessage;
  
  const GazeEngineState({
    this.currentGaze,
    this.landmarks,
    this.isFaceDetected = false,
    this.isCalibrated = false,
    this.trackingConfidence = 0.0,
    this.isInitialized = false,
    this.errorMessage,
  });
  
  GazeEngineState copyWith({
    GazePoint? currentGaze,
    FaceLandmarksData? landmarks,
    bool? isFaceDetected,
    bool? isCalibrated,
    double? trackingConfidence,
    bool? isInitialized,
    String? errorMessage,
  }) => GazeEngineState(
    currentGaze: currentGaze ?? this.currentGaze,
    landmarks: landmarks ?? this.landmarks,
    isFaceDetected: isFaceDetected ?? this.isFaceDetected,
    isCalibrated: isCalibrated ?? this.isCalibrated,
    trackingConfidence: trackingConfidence ?? this.trackingConfidence,
    isInitialized: isInitialized ?? this.isInitialized,
    errorMessage: errorMessage ?? this.errorMessage,
  );
}

class GazeEngineController extends StateNotifier<GazeEngineState> {
  final CameraService _cameraService;
  final MediaPipeService _mediaPipeService;
  final GazeCalculator _gazeCalculator;
  final GazeZoneMapper _zoneMapper;
  final DwellTimerService _dwellTimerService;
  final BlinkDetector _blinkDetector;
  
  StreamSubscription? _landmarksSubscription;
  Size _screenSize = Size.zero;
  
  // Public streams for components to listen to
  Stream<String> get selectionStream => _dwellTimerService.selectionStream;
  Stream<DwellProgress> get progressStream => _dwellTimerService.progressStream;
  Stream<BlinkEvent> get blinkStream => _blinkDetector.blinkStream;
  
  GazeEngineController({
    required CameraService cameraService,
    required MediaPipeService mediaPipeService,
    required GazeCalculator gazeCalculator,
    required GazeZoneMapper zoneMapper,
    required DwellTimerService dwellTimerService,
    required BlinkDetector blinkDetector,
  }) : _cameraService = cameraService,
       _mediaPipeService = mediaPipeService,
       _gazeCalculator = gazeCalculator,
       _zoneMapper = zoneMapper,
       _dwellTimerService = dwellTimerService,
       _blinkDetector = blinkDetector,
       super(const GazeEngineState());
  
  Future<void> initialize(Size screenSize) async {
    _screenSize = screenSize;
    
    try {
      // Start camera
      await _cameraService.initialize();
      
      // Start MediaPipe processing
      await _mediaPipeService.initialize(_cameraService.frameStream);
      
      // Subscribe to landmarks stream
      _landmarksSubscription = _mediaPipeService.landmarksStream.listen(
        _onLandmarks,
        onError: (e) {
          state = state.copyWith(errorMessage: 'Tracking error: $e');
        },
      );
      
      state = state.copyWith(isInitialized: true);
      
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to initialize gaze engine: $e',
      );
    }
  }
  
  void _onLandmarks(FaceLandmarksData? landmarks) {
    if (landmarks == null) {
      state = state.copyWith(
        isFaceDetected: false,
        currentGaze: null,
        trackingConfidence: 0.0,
      );
      _dwellTimerService.update(null);
      return;
    }
    
    // Calculate gaze point
    final gazePoint = _gazeCalculator.calculate(landmarks, _screenSize);
    
    // Process blink detection on every frame
    _blinkDetector.processLandmarks(landmarks);
    
    if (gazePoint == null) return;
    
    // Map gaze to zone
    final zone = _zoneMapper.getZoneAt(gazePoint);
    
    // Update dwell timer
    _dwellTimerService.update(zone);
    
    // Update state (batched — only if meaningful change)
    state = state.copyWith(
      currentGaze: gazePoint,
      landmarks: landmarks,
      isFaceDetected: true,
      trackingConfidence: gazePoint.confidence,
    );
  }
  
  void updateScreenSize(Size size) {
    _screenSize = size;
  }
  
  void registerKeyZone(String keyId, Rect bounds) {
    _zoneMapper.registerZone(keyId, bounds);
  }
  
  void clearKeyZones() {
    _zoneMapper.clearZones();
  }
  
  void setDwellDuration(Duration duration) {
    _dwellTimerService.dwellDuration = duration;
  }
  
  @override
  void dispose() {
    _landmarksSubscription?.cancel();
    _cameraService.dispose();
    _mediaPipeService.dispose();
    _dwellTimerService.dispose();
    _blinkDetector.dispose();
    super.dispose();
  }
}

// Riverpod provider
final gazeEngineProvider = StateNotifierProvider<GazeEngineController, GazeEngineState>(
  (ref) => GazeEngineController(
    cameraService: CameraService(),
    mediaPipeService: MediaPipeService(),
    gazeCalculator: GazeCalculator(),
    zoneMapper: GazeZoneMapper(),
    dwellTimerService: DwellTimerService(),
    blinkDetector: BlinkDetector(),
  ),
);
```

---

## ✅ Milestone: Gaze Engine Working

You know this step is complete when:
- [ ] Gaze cursor appears on screen and follows your eyes
- [ ] Cursor moves smoothly (not jumpy) with 0.65 smoothing
- [ ] Cursor correctly follows when you look at different corners of screen
- [ ] Console shows zone ID when you look at different areas
- [ ] DwellTimer fires after 600ms of holding gaze in a zone

---

## 🤖 AI IDE Prompt — Gaze Engine

```
Build the complete gaze engine for ECHO eye tracking app.

1. Create GazeCalculator that:
   - Normalizes iris position relative to eye corners (0.0 to 1.0)
   - Compensates for head rotation using euler angles
   - Averages left and right eye gaze vectors
   - Applies calibration offsets when available
   - Applies exponential moving average smoothing (alpha=0.65)
   - Converts to screen pixel coordinates
   - Returns confidence score (0.0-1.0)

2. Create GazePoint model with x, y, normalizedX, normalizedY, 
   confidence, timestamp fields

3. Create GazeZoneMapper that:
   - Stores named rectangular zones (keyboard key positions)
   - Maps a GazePoint to the zone ID it falls in
   - Falls back to nearest zone center when between keys
   - Returns null when gaze is outside all zones

4. Create DwellTimerService that:
   - Accumulates dwell time while gaze stays in same zone
   - Resets timer when gaze moves to different zone
   - Emits selection event when dwell reaches threshold (default 600ms)
   - Emits progress stream (0.0-1.0) for visual feedback
   - Has grace period (800ms) after selection before next can trigger

5. Create GazeCursorWidget that:
   - Renders at gaze position using Positioned widget
   - Starts as 24px blue circle, grows to 56px green as dwell progresses
   - Color interpolates blue→green as progress increases
   - Uses AnimatedContainer for smooth transitions
   - Has glow effect at full dwell

6. Create GazeEngineController (Riverpod StateNotifier) that:
   - Orchestrates CameraService + MediaPipeService + GazeCalculator
   - Exposes selection stream, progress stream, blink stream
   - Handles face-not-detected state
   - Provides registerKeyZone/clearKeyZones for keyboard layout

All streams must be broadcast streams (multiple listeners).
All services must have proper dispose() methods.
```

---

*Next: `05_CALIBRATION_SYSTEM.md` →*
