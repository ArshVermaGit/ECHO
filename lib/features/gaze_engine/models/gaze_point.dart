class GazePoint {
  final double x;
  final double y;
  final double confidence;
  final DateTime timestamp;

  GazePoint({
    required this.x,
    required this.y,
    required this.confidence,
    required this.timestamp,
  });

  @override
  String toString() => 'GazePoint(x: $x, y: $y, confidence: $confidence)';
}
