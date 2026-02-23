# 03 — Camera & MediaPipe
## ECHO AAC | Face Mesh, Iris Tracking, Blink Detection

---

## What We're Building

The entire ECHO app is built on one foundation: **reading where someone is looking using only a phone camera**. This file covers everything from opening the camera to having reliable, real-time blink detection and gaze vectors ready for the keyboard.

### What MediaPipe Face Mesh Gives Us
- **468 facial landmarks** at 60fps — points covering the entire face
- **Iris landmarks (points 468-477)** — the center and boundary of each iris
- These iris landmarks are the key to gaze estimation
- Additionally: eyelid landmarks — essential for blink detection

---

## Understanding the Eye Landmarks

```
Face Mesh Eye Landmarks (MediaPipe numbering):

RIGHT EYE (from camera's perspective = left eye of person):
  Outer corner: 33
  Inner corner: 133
  Upper lid top: 159
  Lower lid bottom: 145
  Iris center: 468
  Iris boundary: 469, 470, 471, 472

LEFT EYE (from camera's perspective = right eye of person):
  Outer corner: 362
  Inner corner: 263
  Upper lid top: 386
  Lower lid bottom: 374
  Iris center: 473
  Iris boundary: 474, 475, 476, 477

EAR (Eye Aspect Ratio) calculation uses:
  Right eye: landmarks 159, 145, 33, 133 (top, bottom, corners)
  Left eye: landmarks 386, 374, 362, 263
```

---

## Step 1: Camera Service

Create `lib/features/gaze_engine/services/camera_service.dart`:

```dart
import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Manages the camera lifecycle and provides a stream of camera frames
/// for processing by MediaPipe.
/// 
/// Key design decisions:
/// - Always uses FRONT camera (for face/eye tracking)
/// - Targets 60fps but falls back gracefully to available fps
/// - Provides raw YUV420 frames for MediaPipe (NOT JPEG — faster)
/// - Handles camera lifecycle (pause on background, resume on foreground)
class CameraService {
  CameraController? _controller;
  final _frameStreamController = StreamController<CameraImage>.broadcast();
  bool _isProcessingFrame = false;
  List<CameraDescription> _cameras = [];

  /// Stream of camera frames — subscribers (MediaPipe) listen to this
  Stream<CameraImage> get frameStream => _frameStreamController.stream;
  
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  CameraController? get controller => _controller;

  Future<void> initialize() async {
    try {
      _cameras = await availableCameras();
      
      // Find front-facing camera
      final frontCamera = _cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );
      
      // Initialize with high resolution for better iris detection
      // Use medium if performance issues arise
      _controller = CameraController(
        frontCamera,
        ResolutionPreset.high,  // 1280x720 — good balance of quality vs performance
        enableAudio: false,      // No audio needed — save battery
        imageFormatGroup: ImageFormatGroup.yuv420,  // Best for ML processing
      );
      
      await _controller!.initialize();
      
      // Set focus mode to auto — helps with varying distances
      await _controller!.setFocusMode(FocusMode.auto);
      
      // Start the image stream
      await _controller!.startImageStream(_onCameraFrame);
      
    } on CameraException catch (e) {
      throw CameraInitializationException(
        'Failed to initialize camera: ${e.description}',
        code: e.code,
      );
    }
  }

  void _onCameraFrame(CameraImage image) {
    // CRITICAL: Skip frame if still processing previous one
    // This prevents frame queue buildup which causes lag
    if (_isProcessingFrame) return;
    
    if (!_frameStreamController.isClosed) {
      _frameStreamController.add(image);
    }
  }

  /// Called by MediaPipe service to signal frame processing start/end
  void markFrameProcessingStart() => _isProcessingFrame = true;
  void markFrameProcessingEnd() => _isProcessingFrame = false;

  Future<void> pause() async {
    await _controller?.stopImageStream();
  }

  Future<void> resume() async {
    if (_controller?.value.isInitialized == true && 
        !_controller!.value.isStreamingImages) {
      await _controller!.startImageStream(_onCameraFrame);
    }
  }

  Future<void> dispose() async {
    await _controller?.stopImageStream();
    await _controller?.dispose();
    await _frameStreamController.close();
    _controller = null;
  }
}

class CameraInitializationException implements Exception {
  final String message;
  final String? code;
  const CameraInitializationException(this.message, {this.code});
  
  @override
  String toString() => 'CameraInitializationException: $message (code: $code)';
}
```

---

## Step 2: MediaPipe Service

Create `lib/features/gaze_engine/services/mediapipe_service.dart`:

```dart
import 'dart:async';
import 'dart:isolate';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/foundation.dart';
import '../models/face_landmarks.dart';

/// Wraps Google ML Kit Face Detection to extract facial landmarks at 60fps.
/// 
/// ML Kit's Face Mesh gives us 468 landmarks including iris landmarks (468-477)
/// which are the foundation of our gaze tracking.
///
/// Performance strategy:
/// - Process on compute isolate to avoid blocking UI thread
/// - Use FaceDetectorMode.stream for faster processing (vs accurate mode)
/// - Enable classification for blink probability
class MediaPipeService {
  late FaceDetector _faceDetector;
  StreamSubscription? _cameraSubscription;
  final _landmarksController = StreamController<FaceLandmarksData?>.broadcast();
  
  bool _isInitialized = false;
  
  Stream<FaceLandmarksData?> get landmarksStream => _landmarksController.stream;

  Future<void> initialize(Stream<CameraImage> cameraStream) async {
    // Configure face detector for maximum landmark detail
    final options = FaceDetectorOptions(
      // Enable landmarks — gives us eye corners, nose, mouth
      enableLandmarks: true,
      // Enable classification — gives us blink probabilities (0.0 - 1.0)
      enableClassification: true,
      // Enable contours — gives us the full 468 face mesh
      enableContours: true,
      // Stream mode is faster than accurate mode — perfect for real-time
      performanceMode: FaceDetectorMode.fast,
      // Only detect 1 face — we're focused on the patient
      minFaceSize: 0.15,
    );
    
    _faceDetector = FaceDetector(options: options);
    _isInitialized = true;
    
    // Subscribe to camera frames
    _cameraSubscription = cameraStream.listen(_processFrame);
  }

  Future<void> _processFrame(CameraImage image) async {
    if (!_isInitialized) return;
    
    try {
      // Convert CameraImage to InputImage for ML Kit
      final inputImage = _convertToInputImage(image);
      if (inputImage == null) return;
      
      // Process the frame — this runs ML inference
      final faces = await _faceDetector.processImage(inputImage);
      
      if (faces.isEmpty) {
        // No face detected — emit null so UI shows "no face" warning
        _landmarksController.add(null);
        return;
      }
      
      // Take the first (and should be only) face
      final face = faces.first;
      
      // Extract landmarks into our model
      final landmarks = FaceLandmarksData.fromMlKitFace(face);
      _landmarksController.add(landmarks);
      
    } catch (e) {
      debugPrint('MediaPipe processing error: $e');
      // Don't emit error — just skip this frame silently
    }
  }

  InputImage? _convertToInputImage(CameraImage image) {
    try {
      // Convert YUV420 camera frame to ML Kit InputImage
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();
      
      final imageSize = Size(
        image.width.toDouble(), 
        image.height.toDouble(),
      );
      
      // Front camera images are typically rotated 270 degrees on Android
      // This must match actual rotation or landmarks will be mirrored/wrong
      const imageRotation = InputImageRotation.rotation270deg;
      
      final inputImageFormat = InputImageFormatValue.fromRawValue(
        image.format.raw,
      );
      if (inputImageFormat == null) return null;
      
      final metadata = InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes.first.bytesPerRow,
      );
      
      return InputImage.fromBytes(bytes: bytes, metadata: metadata);
    } catch (e) {
      return null;
    }
  }

  Future<void> dispose() async {
    await _cameraSubscription?.cancel();
    await _faceDetector.close();
    await _landmarksController.close();
    _isInitialized = false;
  }
}
```

---

## Step 3: Face Landmarks Model

Create `lib/features/gaze_engine/models/face_landmarks.dart`:

```dart
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/foundation.dart';

/// Wrapper around ML Kit face detection results.
/// Provides clean access to the landmarks we care about.
@immutable
class FaceLandmarksData {
  // Raw landmark list (468 points)
  final List<Point<double>> landmarks;
  
  // Computed values we extract frequently
  final Point<double> rightIrisCenter;   // Landmark 468
  final Point<double> leftIrisCenter;    // Landmark 473
  
  // Eye corners for EAR calculation
  final Point<double> rightEyeOuter;     // Landmark 33
  final Point<double> rightEyeInner;     // Landmark 133
  final Point<double> rightEyeTop;       // Landmark 159
  final Point<double> rightEyeBottom;    // Landmark 145
  
  final Point<double> leftEyeOuter;      // Landmark 362
  final Point<double> leftEyeInner;      // Landmark 263
  final Point<double> leftEyeTop;        // Landmark 386
  final Point<double> leftEyeBottom;     // Landmark 374
  
  // ML Kit's built-in blink probability (0.0 = open, 1.0 = closed)
  final double rightEyeOpenProbability;
  final double leftEyeOpenProbability;
  
  // Head pose for gaze compensation
  final double headEulerX;  // Pitch (nodding)
  final double headEulerY;  // Yaw (turning)
  final double headEulerZ;  // Roll (tilting)
  
  // Bounding box of the face (for UI display)
  final Rect boundingBox;
  
  const FaceLandmarksData({
    required this.landmarks,
    required this.rightIrisCenter,
    required this.leftIrisCenter,
    required this.rightEyeOuter,
    required this.rightEyeInner,
    required this.rightEyeTop,
    required this.rightEyeBottom,
    required this.leftEyeOuter,
    required this.leftEyeInner,
    required this.leftEyeTop,
    required this.leftEyeBottom,
    required this.rightEyeOpenProbability,
    required this.leftEyeOpenProbability,
    required this.headEulerX,
    required this.headEulerY,
    required this.headEulerZ,
    required this.boundingBox,
  });

  factory FaceLandmarksData.fromMlKitFace(Face face) {
    // ML Kit provides contours — we extract the points we need
    final allContours = face.contours;
    
    // Get face mesh points — these are the 468 landmarks
    final faceContour = allContours[FaceContourType.face];
    
    // Extract specific eye landmarks from contours
    final rightEyeContour = allContours[FaceContourType.rightEye];
    final leftEyeContour = allContours[FaceContourType.leftEye];
    
    // Helper to safely get a contour point
    Point<double> safePoint(FaceContour? contour, int index, double fallbackX, double fallbackY) {
      if (contour == null || contour.points.isEmpty) {
        return Point(fallbackX, fallbackY);
      }
      final safeIndex = index.clamp(0, contour.points.length - 1);
      final p = contour.points[safeIndex];
      return Point(p.x.toDouble(), p.y.toDouble());
    }
    
    // Convert ML Kit landmarks to our Point format
    final landmarks = faceContour?.points
        .map((p) => Point(p.x.toDouble(), p.y.toDouble()))
        .toList() ?? [];
    
    // ML Kit provides blink probabilities directly
    final rightOpen = face.rightEyeOpenProbability ?? 1.0;
    final leftOpen = face.leftEyeOpenProbability ?? 1.0;
    
    // Extract eye corner and lid points from contours
    // Right eye contour points: [outer, top-outer, top, top-inner, inner, bottom-inner, bottom, bottom-outer]
    final rightOuter = safePoint(rightEyeContour, 0, 0, 0);
    final rightTop = safePoint(rightEyeContour, 2, 0, 0);
    final rightInner = safePoint(rightEyeContour, 4, 0, 0);
    final rightBottom = safePoint(rightEyeContour, 6, 0, 0);
    
    final leftOuter = safePoint(leftEyeContour, 0, 0, 0);
    final leftTop = safePoint(leftEyeContour, 2, 0, 0);
    final leftInner = safePoint(leftEyeContour, 4, 0, 0);
    final leftBottom = safePoint(leftEyeContour, 6, 0, 0);
    
    // For iris center, we use the center of the eye contour 
    // (ML Kit doesn't expose raw iris landmarks in the standard API)
    final rightIrisCenterX = (rightOuter.x + rightInner.x) / 2;
    final rightIrisCenterY = (rightTop.y + rightBottom.y) / 2;
    final leftIrisCenterX = (leftOuter.x + leftInner.x) / 2;
    final leftIrisCenterY = (leftTop.y + leftBottom.y) / 2;
    
    return FaceLandmarksData(
      landmarks: landmarks,
      rightIrisCenter: Point(rightIrisCenterX, rightIrisCenterY),
      leftIrisCenter: Point(leftIrisCenterX, leftIrisCenterY),
      rightEyeOuter: rightOuter,
      rightEyeInner: rightInner,
      rightEyeTop: rightTop,
      rightEyeBottom: rightBottom,
      leftEyeOuter: leftOuter,
      leftEyeInner: leftInner,
      leftEyeTop: leftTop,
      leftEyeBottom: leftBottom,
      rightEyeOpenProbability: rightOpen,
      leftEyeOpenProbability: leftOpen,
      headEulerX: face.headEulerAngleX ?? 0.0,
      headEulerY: face.headEulerAngleY ?? 0.0,
      headEulerZ: face.headEulerAngleZ ?? 0.0,
      boundingBox: face.boundingBox,
    );
  }
  
  /// Computed EAR (Eye Aspect Ratio) for blink detection
  /// EAR = (vertical distances) / (2 * horizontal distance)
  /// EAR < 0.2 typically means eye is closed
  double get rightEAR => _calculateEAR(
    rightEyeTop, rightEyeBottom, rightEyeOuter, rightEyeInner,
  );
  
  double get leftEAR => _calculateEAR(
    leftEyeTop, leftEyeBottom, leftEyeOuter, leftEyeInner,
  );
  
  double get averageEAR => (rightEAR + leftEAR) / 2;
  
  double _calculateEAR(
    Point<double> top, Point<double> bottom,
    Point<double> outer, Point<double> inner,
  ) {
    final verticalDist = _distance(top, bottom);
    final horizontalDist = _distance(outer, inner);
    if (horizontalDist == 0) return 1.0;
    return verticalDist / horizontalDist;
  }
  
  double _distance(Point<double> a, Point<double> b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return (dx * dx + dy * dy).sqrt();
  }
}
```

---

## Step 4: Blink Detector

Create `lib/features/gaze_engine/services/blink_detector.dart`:

```dart
import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../models/face_landmarks.dart';

enum BlinkType { single, double_, long }

@immutable
class BlinkEvent {
  final BlinkType type;
  final DateTime timestamp;
  final Duration duration;
  
  const BlinkEvent({
    required this.type,
    required this.timestamp,
    required this.duration,
  });
}

/// Detects blinks from facial landmarks stream.
/// 
/// How it works:
/// 1. Monitors EAR (Eye Aspect Ratio) on every frame
/// 2. When EAR drops below threshold → blink started
/// 3. When EAR rises back → blink ended, duration calculated
/// 4. Analyzes pattern: single blink, double blink (emergency), long blink
///
/// Blink thresholds (tuneable per user in calibration):
/// - EAR < 0.2 = eye closed
/// - Duration 80-400ms = voluntary blink
/// - Duration > 800ms = intentional long blink (alternate input)
/// - Two blinks within 800ms = double blink (EMERGENCY trigger)
class BlinkDetector {
  // EAR threshold — below this = eye is closed
  // This can be personalized per user in calibration
  double earThreshold;
  
  // Timing parameters
  final Duration minBlinkDuration;
  final Duration maxBlinkDuration;
  final Duration doubleBinkWindow;
  
  final _blinkController = StreamController<BlinkEvent>.broadcast();
  Stream<BlinkEvent> get blinkStream => _blinkController.stream;
  
  // State tracking
  bool _isBlinking = false;
  DateTime? _blinkStartTime;
  final Queue<DateTime> _recentBlinks = Queue();
  
  BlinkDetector({
    this.earThreshold = 0.20,
    this.minBlinkDuration = const Duration(milliseconds: 80),
    this.maxBlinkDuration = const Duration(milliseconds: 600),
    this.doubleBinkWindow = const Duration(milliseconds: 800),
  });
  
  /// Process a new frame's landmarks
  void processLandmarks(FaceLandmarksData landmarks) {
    final currentEAR = landmarks.averageEAR;
    final now = DateTime.now();
    
    if (!_isBlinking && currentEAR < earThreshold) {
      // Blink started
      _isBlinking = true;
      _blinkStartTime = now;
      
    } else if (_isBlinking && currentEAR >= earThreshold) {
      // Blink ended
      _isBlinking = false;
      
      if (_blinkStartTime != null) {
        final duration = now.difference(_blinkStartTime!);
        
        // Validate duration — filter out noise and involuntary micro-blinks
        if (duration >= minBlinkDuration && duration <= maxBlinkDuration) {
          _recordAndClassifyBlink(now, duration);
        } else if (duration > maxBlinkDuration) {
          // Long blink — intentional hold action (alternate input mode)
          if (!_blinkController.isClosed) {
            _blinkController.add(BlinkEvent(
              type: BlinkType.long,
              timestamp: now,
              duration: duration,
            ));
          }
        }
      }
      _blinkStartTime = null;
    }
  }
  
  void _recordAndClassifyBlink(DateTime now, Duration duration) {
    // Clean up old blinks outside the window
    _recentBlinks.removeWhere(
      (t) => now.difference(t) > doubleBinkWindow,
    );
    
    _recentBlinks.add(now);
    
    if (_recentBlinks.length >= 2) {
      // Double blink detected!
      _recentBlinks.clear(); // Reset after triggering
      
      if (!_blinkController.isClosed) {
        _blinkController.add(BlinkEvent(
          type: BlinkType.double_,
          timestamp: now,
          duration: duration,
        ));
      }
    } else {
      // Single blink
      if (!_blinkController.isClosed) {
        _blinkController.add(BlinkEvent(
          type: BlinkType.single,
          timestamp: now,
          duration: duration,
        ));
      }
    }
  }
  
  void dispose() {
    _blinkController.close();
  }
}
```

---

## Step 5: Camera Preview Widget

Create `lib/features/gaze_engine/widgets/camera_preview_widget.dart`:

```dart
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Shows the live camera feed with optional debug overlay.
/// 
/// In production (non-debug mode), this is shown as a small 
/// thumbnail in the corner — not full screen. The patient 
/// doesn't need to see a big camera view.
/// 
/// During calibration, it's shown larger.
class EchoCameraPreview extends StatelessWidget {
  final CameraController controller;
  final bool showDebugOverlay;
  final double size;
  
  const EchoCameraPreview({
    super.key,
    required this.controller,
    this.showDebugOverlay = false,
    this.size = 80,
  });
  
  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return SizedBox(
        width: size,
        height: size,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withOpacity(0.5),
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Mirror the front camera feed
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(3.14159), // Horizontal flip
            child: CameraPreview(controller),
          ),
          
          // Green "tracking" indicator dot
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## Step 6: Testing the Camera Pipeline

Create `test/unit/camera_pipeline_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_aac/features/gaze_engine/services/blink_detector.dart';
import 'package:echo_aac/features/gaze_engine/models/face_landmarks.dart';

void main() {
  group('BlinkDetector', () {
    late BlinkDetector detector;
    
    setUp(() {
      detector = BlinkDetector(
        earThreshold: 0.20,
        minBlinkDuration: const Duration(milliseconds: 80),
        doubleBinkWindow: const Duration(milliseconds: 800),
      );
    });
    
    tearDown(() => detector.dispose());
    
    test('detects single blink from EAR dropping', () async {
      final blinks = <BlinkEvent>[];
      detector.blinkStream.listen(blinks.add);
      
      // Simulate eye open (EAR 0.35) → closed (EAR 0.12) → open (EAR 0.35)
      // with realistic timing
      
      // Eye open - 5 frames
      for (int i = 0; i < 5; i++) {
        detector.processLandmarks(createMockLandmarks(ear: 0.35));
        await Future.delayed(const Duration(milliseconds: 16));
      }
      
      // Eye closing and closed - 8 frames (~130ms)
      for (int i = 0; i < 8; i++) {
        detector.processLandmarks(createMockLandmarks(ear: 0.12));
        await Future.delayed(const Duration(milliseconds: 16));
      }
      
      // Eye open again
      detector.processLandmarks(createMockLandmarks(ear: 0.35));
      
      await Future.delayed(const Duration(milliseconds: 50));
      
      expect(blinks.length, 1);
      expect(blinks.first.type, BlinkType.single);
    });
    
    // TODO: Add double-blink test, long-blink test
  });
}

FaceLandmarksData createMockLandmarks({required double ear}) {
  // Creates a minimal FaceLandmarksData for testing
  // with the given EAR value
  // Implementation uses simple points to achieve desired EAR
  final top = Point<double>(0, 0);
  final bottom = Point<double>(0, ear * 100); // Simple mock
  final outer = Point<double>(0, 0);
  final inner = Point<double>(100, 0);
  
  return FaceLandmarksData(
    landmarks: [],
    rightIrisCenter: const Point(50, 50),
    leftIrisCenter: const Point(50, 50),
    rightEyeOuter: outer,
    rightEyeInner: inner,
    rightEyeTop: top,
    rightEyeBottom: bottom,
    leftEyeOuter: outer,
    leftEyeInner: inner,
    leftEyeTop: top,
    leftEyeBottom: bottom,
    rightEyeOpenProbability: ear > 0.2 ? 0.9 : 0.1,
    leftEyeOpenProbability: ear > 0.2 ? 0.9 : 0.1,
    headEulerX: 0,
    headEulerY: 0,
    headEulerZ: 0,
    boundingBox: Rect.zero,
  );
}
```

---

## 🔍 Debugging Face Detection

Add this debug widget to see raw landmark positions during development:

```dart
// Add to camera preview during development
Widget buildDebugOverlay(FaceLandmarksData? landmarks) {
  if (landmarks == null) return const SizedBox();
  
  return CustomPaint(
    painter: LandmarkPainter(landmarks),
  );
}

class LandmarkPainter extends CustomPainter {
  final FaceLandmarksData landmarks;
  
  LandmarkPainter(this.landmarks);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2
      ..style = PaintingStyle.fill;
    
    final irisPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    
    // Draw all face landmarks as small dots
    for (final point in landmarks.landmarks) {
      canvas.drawCircle(
        Offset(point.x * size.width, point.y * size.height),
        2,
        paint,
      );
    }
    
    // Draw iris centers as larger circles
    canvas.drawCircle(
      Offset(landmarks.rightIrisCenter.x * size.width, 
             landmarks.rightIrisCenter.y * size.height),
      8, irisPaint,
    );
    
    canvas.drawCircle(
      Offset(landmarks.leftIrisCenter.x * size.width,
             landmarks.leftIrisCenter.y * size.height),
      8, irisPaint,
    );
  }
  
  @override
  bool shouldRepaint(covariant LandmarkPainter oldDelegate) => true;
}
```

---

## ✅ Milestone: Camera + MediaPipe Working

You know this step is complete when:
- [ ] App opens front camera without crashing
- [ ] Camera preview shows in corner of screen
- [ ] MediaPipe detects face within 1 second of camera opening
- [ ] Console logs show 468 landmarks per frame
- [ ] BlinkDetector logs "BLINK DETECTED" when you physically blink at the camera
- [ ] Test suite passes

---

## 🤖 AI IDE Prompt — Camera + MediaPipe

```
Build the complete camera + MediaPipe pipeline for ECHO:

1. Create CameraService that:
   - Opens front-facing camera at high resolution
   - Streams CameraImage frames at 60fps
   - Handles YUV420 format for ML processing
   - Has pause/resume/dispose lifecycle methods
   - Prevents frame queue buildup (skip frames if previous unprocessed)

2. Create MediaPipeService that:
   - Accepts Stream<CameraImage> from CameraService
   - Uses google_mlkit_face_detection with contours enabled
   - Extracts eye corner landmarks and iris center positions
   - Provides blink open probability from ML Kit classification
   - Emits Stream<FaceLandmarksData?> (null when no face detected)

3. Create FaceLandmarksData model with:
   - All 8 eye corner/lid points (4 per eye)
   - Both iris center positions
   - Left and right eye open probability
   - Head euler angles (pitch, yaw, roll)
   - Computed EAR (Eye Aspect Ratio) getters

4. Create BlinkDetector that:
   - Monitors EAR on every frame
   - Detects blink start (EAR drops below 0.20) and end (EAR rises)
   - Classifies: single blink, double blink (within 800ms), long blink (>600ms)
   - Emits Stream<BlinkEvent>

5. Create EchoCameraPreview widget that shows small camera thumbnail
   with mirrored front camera feed and green tracking indicator

6. Add debug mode LandmarkPainter that visualizes all face mesh points
   and highlights iris centers in blue

Test: All unit tests pass, app runs on physical device, blinks are logged.
```

---

*Next: `04_GAZE_ENGINE.md` →*
