/// Type of entrance point
enum EntranceType {
  entrance, // Entry point for vehicles
  exit, // Exit point for vehicles
}

/// Model representing an entrance or exit point in the parking lot
/// Entrances must be attached to roads for pathfinding to work
class Entrance {
  final String id;
  double x;
  double y;
  double width;
  double height;
  EntranceType type;
  String? attachedRoadId; // ID of the road this entrance is attached to

  Entrance({
    required this.id,
    required this.x,
    required this.y,
    this.width = 60,
    this.height = 60,
    required this.type,
    this.attachedRoadId,
  });

  /// Create a copy of this entrance with optional overrides
  Entrance copyWith({
    String? id,
    double? x,
    double? y,
    double? width,
    double? height,
    EntranceType? type,
    String? attachedRoadId,
  }) {
    return Entrance(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      type: type ?? this.type,
      attachedRoadId: attachedRoadId ?? this.attachedRoadId,
    );
  }

  /// Convert entrance to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'type': type.name,
      'attachedRoadId': attachedRoadId,
    };
  }

  /// Create entrance from JSON
  factory Entrance.fromJson(Map<String, dynamic> json) {
    return Entrance(
      id: json['id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num?)?.toDouble() ?? 60,
      height: (json['height'] as num?)?.toDouble() ?? 60,
      type: EntranceType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => EntranceType.entrance,
      ),
      attachedRoadId: json['attachedRoadId'] as String?,
    );
  }

  /// Get the center point of this entrance
  ({double x, double y}) get center => (x: x + width / 2, y: y + height / 2);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Entrance && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
