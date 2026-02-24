import 'dart:ui';

enum GazeZoneType {
  keyboard,
  messageBar,
  predictionCards,
  phraseBoards,
  unknown;
}

class GazeZone {
  final GazeZoneType type;
  final Rect bounds;
  final String? identifier;

  GazeZone({
    required this.type,
    required this.bounds,
    this.identifier,
  });
}
