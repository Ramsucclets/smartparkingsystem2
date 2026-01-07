import 'dart:convert';
import 'parking_spot.dart';
import 'road.dart';
import 'obstacle.dart';
import 'entrance.dart';

class ParkingGrid {
  String name;
  double canvasWidth;
  double canvasHeight;
  double gridSize;
  List<ParkingSpot> spots;
  List<Road> roads;
  List<Obstacle> obstacles;
  Entrance? entrance;
  Entrance? exit;
  DateTime createdAt;
  DateTime? updatedAt;

  ParkingGrid({
    required this.name,
    this.canvasWidth = 800,
    this.canvasHeight = 600,
    this.gridSize = 20,
    List<ParkingSpot>? spots,
    List<Road>? roads,
    List<Obstacle>? obstacles,
    this.entrance,
    this.exit,
    DateTime? createdAt,
    this.updatedAt,
  })  : spots = spots ?? [],
        roads = roads ?? [],
        obstacles = obstacles ?? [],
        createdAt = createdAt ?? DateTime.now();

  void addSpot(ParkingSpot spot) {
    spots.add(spot);
    updatedAt = DateTime.now();
  }

  bool removeSpot(String spotId) {
    final lengthBefore = spots.length;
    spots.removeWhere((s) => s.id == spotId);
    if (spots.length != lengthBefore) {
      updatedAt = DateTime.now();
      return true;
    }
    return false;
  }

  ParkingSpot? findSpot(String spotId) {
    try {
      return spots.firstWhere((s) => s.id == spotId);
    } catch (_) {
      return null;
    }
  }

  void addRoad(Road road) {
    roads.add(road);
    updatedAt = DateTime.now();
  }

  bool removeRoad(String roadId) {
    final lengthBefore = roads.length;
    roads.removeWhere((r) => r.id == roadId);
    if (roads.length != lengthBefore) {
      updatedAt = DateTime.now();
      return true;
    }
    return false;
  }

  Road? findRoad(String roadId) {
    try {
      return roads.firstWhere((r) => r.id == roadId);
    } catch (_) {
      return null;
    }
  }

  void addObstacle(Obstacle obstacle) {
    obstacles.add(obstacle);
    updatedAt = DateTime.now();
  }

  bool removeObstacle(String obstacleId) {
    final lengthBefore = obstacles.length;
    obstacles.removeWhere((o) => o.id == obstacleId);
    if (obstacles.length != lengthBefore) {
      updatedAt = DateTime.now();
      return true;
    }
    return false;
  }

  Obstacle? findObstacle(String obstacleId) {
    try {
      return obstacles.firstWhere((o) => o.id == obstacleId);
    } catch (_) {
      return null;
    }
  }

  String generateSpotId() {
    int maxNum = 0;
    for (final spot in spots) {
      final match = RegExp(r'^S(\d+)$').firstMatch(spot.id);
      if (match != null) {
        final num = int.tryParse(match.group(1)!) ?? 0;
        if (num > maxNum) maxNum = num;
      }
    }
    return 'S${maxNum + 1}';
  }

  String generateRoadId() {
    int maxNum = 0;
    for (final road in roads) {
      final match = RegExp(r'^R(\d+)$').firstMatch(road.id);
      if (match != null) {
        final num = int.tryParse(match.group(1)!) ?? 0;
        if (num > maxNum) maxNum = num;
      }
    }
    return 'R${maxNum + 1}';
  }

  String generateObstacleId() {
    int maxNum = 0;
    for (final obstacle in obstacles) {
      final match = RegExp(r'^O(\d+)$').firstMatch(obstacle.id);
      if (match != null) {
        final num = int.tryParse(match.group(1)!) ?? 0;
        if (num > maxNum) maxNum = num;
      }
    }
    return 'O${maxNum + 1}';
  }

  double snapToGrid(double value) {
    return (value / gridSize).round() * gridSize;
  }

  void setEntrance(Entrance newEntrance) {
    entrance = newEntrance;
    updatedAt = DateTime.now();
  }

  void setExit(Entrance newExit) {
    exit = newExit;
    updatedAt = DateTime.now();
  }

  void removeEntrance() {
    entrance = null;
    updatedAt = DateTime.now();
  }

  void removeExit() {
    exit = null;
    updatedAt = DateTime.now();
  }

  bool isPointOnRoad(double x, double y) {
    for (final road in roads) {
      if (x >= road.x &&
          x <= road.x + road.width &&
          y >= road.y &&
          y <= road.y + road.height) {
        return true;
      }
    }
    return false;
  }

  Road? findRoadAtPoint(double x, double y) {
    for (final road in roads) {
      if (x >= road.x &&
          x <= road.x + road.width &&
          y >= road.y &&
          y <= road.y + road.height) {
        return road;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'canvasWidth': canvasWidth,
      'canvasHeight': canvasHeight,
      'gridSize': gridSize,
      'spots': spots.map((s) => s.toJson()).toList(),
      'roads': roads.map((r) => r.toJson()).toList(),
      'obstacles': obstacles.map((o) => o.toJson()).toList(),
      if (entrance != null) 'entrance': entrance!.toJson(),
      if (exit != null) 'exit': exit!.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  String toJsonString() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }

  factory ParkingGrid.fromJson(Map<String, dynamic> json) {
    return ParkingGrid(
      name: json['name'] as String? ?? 'Untitled',
      canvasWidth: (json['canvasWidth'] as num?)?.toDouble() ?? 800,
      canvasHeight: (json['canvasHeight'] as num?)?.toDouble() ?? 600,
      gridSize: (json['gridSize'] as num?)?.toDouble() ?? 20,
      spots: (json['spots'] as List<dynamic>?)
              ?.map((s) => ParkingSpot.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      roads: (json['roads'] as List<dynamic>?)
              ?.map((r) => Road.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      obstacles: (json['obstacles'] as List<dynamic>?)
              ?.map((o) => Obstacle.fromJson(o as Map<String, dynamic>))
              .toList() ??
          [],
      entrance: json['entrance'] != null
          ? Entrance.fromJson(json['entrance'] as Map<String, dynamic>)
          : null,
      exit: json['exit'] != null
          ? Entrance.fromJson(json['exit'] as Map<String, dynamic>)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  factory ParkingGrid.fromJsonString(String jsonString) {
    return ParkingGrid.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  factory ParkingGrid.empty({String name = 'New Parking Grid'}) {
    return ParkingGrid(name: name);
  }
}
