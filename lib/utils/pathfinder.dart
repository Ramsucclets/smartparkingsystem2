import 'dart:collection';
import '../models/parking_grid.dart';

//VERY VERY VERY WIP NOT FOR FINAL IMPLEMENTATION

class PathNode {
  final int x;
  final int y;
  double gCost = double.infinity; // Distance from start
  double hCost = 0; // Heuristic distance to end
  double get fCost => gCost + hCost;
  PathNode? parent;
  bool isWalkable = false;

  PathNode(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PathNode &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// Result of path computation
class PathResult {
  final List<Map<String, double>> path;
  final bool success;
  final String? error;

  PathResult.success(this.path)
      : success = true,
        error = null;
  PathResult.failure(this.error)
      : path = [],
        success = false;
}

/// A* Pathfinder for computing routes in the parking grid
class PathFinder {
  final ParkingGrid grid;
  final double cellSize; 
  late List<List<PathNode>> _nodes;
  late int _gridWidth;
  late int _gridHeight;

  PathFinder(this.grid, {this.cellSize = 20});

  void _initializeGrid() {
    _gridWidth = (grid.canvasWidth / cellSize).ceil();
    _gridHeight = (grid.canvasHeight / cellSize).ceil();

    _nodes = List.generate(
      _gridHeight,
      (y) => List.generate(_gridWidth, (x) => PathNode(x, y)),
    );

    for (int y = 0; y < _gridHeight; y++) {
      for (int x = 0; x < _gridWidth; x++) {
        final worldX = x * cellSize + cellSize / 2;
        final worldY = y * cellSize + cellSize / 2;
        _nodes[y][x].isWalkable = _isOnRoad(worldX, worldY);
        _nodes[y][x].gCost = double.infinity;
        _nodes[y][x].hCost = 0;
        _nodes[y][x].parent = null;
      }
    }
  }

  bool _isOnRoad(double x, double y) {
    for (final road in grid.roads) {
      if (x >= road.x &&
          x <= road.x + road.width &&
          y >= road.y &&
          y <= road.y + road.height) {
        return true;
      }
    }
    return false;
  }

  (int, int) _worldToGrid(double x, double y) {
    return (
      (x / cellSize).floor().clamp(0, _gridWidth - 1),
      (y / cellSize).floor().clamp(0, _gridHeight - 1),
    );
  }

  Map<String, double> _gridToWorld(int x, int y) {
    return {
      'x': x * cellSize + cellSize / 2,
      'y': y * cellSize + cellSize / 2,
    };
  }

  PathResult findPath(double startX, double startY, double endX, double endY) {
    _initializeGrid();

    final (startGridX, startGridY) = _worldToGrid(startX, startY);
    final (endGridX, endGridY) = _worldToGrid(endX, endY);

    final startNode = _nodes[startGridY][startGridX];
    final endNode = _nodes[endGridY][endGridX];

    if (!startNode.isWalkable) {
      return PathResult.failure('Start position is not on a road');
    }


    // A* algorithm using a priority queue
    final openSet = SplayTreeSet<PathNode>((a, b) {
      final fCompare = a.fCost.compareTo(b.fCost);
      if (fCompare != 0) return fCompare;
      final hCompare = a.hCost.compareTo(b.hCost);
      if (hCompare != 0) return hCompare;
      final xCompare = a.x.compareTo(b.x);
      if (xCompare != 0) return xCompare;
      return a.y.compareTo(b.y);
    });

    final closedSet = <PathNode>{};

    startNode.gCost = 0;
    startNode.hCost = _heuristic(startNode, endNode);
    openSet.add(startNode);

    PathNode? closestToEnd;
    double closestDistance = double.infinity;

    while (openSet.isNotEmpty) {
      final current = openSet.first;
      openSet.remove(current);

      final distToEnd = _heuristic(current, endNode);
      if (distToEnd < closestDistance) {
        closestDistance = distToEnd;
        closestToEnd = current;
      }

      if (current == endNode) {
        return PathResult.success(_reconstructPath(endNode));
      }

      closedSet.add(current);

      for (final neighbor in _getNeighbors(current)) {
        if (closedSet.contains(neighbor) || !neighbor.isWalkable) continue;

        final tentativeGCost = current.gCost + _distance(current, neighbor);

        if (tentativeGCost < neighbor.gCost) {
          openSet.remove(neighbor); // Remove if present
          neighbor.parent = current;
          neighbor.gCost = tentativeGCost;
          neighbor.hCost = _heuristic(neighbor, endNode);
          openSet.add(neighbor);
        }
      }
    }

    // If we couldn't reach the exact destination, use the closest walkable node
    if (closestToEnd != null && closestDistance < cellSize * 3) {
      return PathResult.success(_reconstructPath(closestToEnd));
    }

    return PathResult.failure(
        'No path found - spot may not be connected to roads');
  }

  /// Manhattan distance heuristic
  double _heuristic(PathNode a, PathNode b) {
    return ((a.x - b.x).abs() + (a.y - b.y).abs()).toDouble() * cellSize;
  }

  /// Euclidean distance between adjacent nodes
  double _distance(PathNode a, PathNode b) {
    final dx = (a.x - b.x).abs();
    final dy = (a.y - b.y).abs();
    // Diagonal movement costs more (sqrt(2) ≈ 1.414)
    if (dx == 1 && dy == 1) {
      return cellSize * 1.414;
    }
    return cellSize;
  }

  /// Get walkable neighbors of a node (8-directional movement)
  List<PathNode> _getNeighbors(PathNode node) {
    final neighbors = <PathNode>[];
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;

        final nx = node.x + dx;
        final ny = node.y + dy;

        if (nx >= 0 && nx < _gridWidth && ny >= 0 && ny < _gridHeight) {
          // For diagonal movement, check that cardinal directions are also walkable
          // This prevents cutting through corners
          if (dx != 0 && dy != 0) {
            if (!_nodes[node.y][node.x + dx].isWalkable ||
                !_nodes[node.y + dy][node.x].isWalkable) {
              continue;
            }
          }
          neighbors.add(_nodes[ny][nx]);
        }
      }
    }
    return neighbors;
  }

  /// Reconstruct the path from end node to start by following parent pointers
  List<Map<String, double>> _reconstructPath(PathNode endNode) {
    final path = <Map<String, double>>[];
    PathNode? current = endNode;

    while (current != null) {
      path.insert(0, _gridToWorld(current.x, current.y));
      current = current.parent;
    }

    // Simplify path by removing collinear points
    return _simplifyPath(path);
  }

  /// Remove unnecessary waypoints that lie on a straight line
  List<Map<String, double>> _simplifyPath(List<Map<String, double>> path) {
    if (path.length <= 2) return path;

    final simplified = <Map<String, double>>[path.first];

    for (int i = 1; i < path.length - 1; i++) {
      final prev = simplified.last;
      final curr = path[i];
      final next = path[i + 1];

      // Check if current point is on the line between prev and next
      final dx1 = curr['x']! - prev['x']!;
      final dy1 = curr['y']! - prev['y']!;
      final dx2 = next['x']! - curr['x']!;
      final dy2 = next['y']! - curr['y']!;

      // Cross product to check collinearity
      final cross = dx1 * dy2 - dy1 * dx2;

      // If not collinear, keep this point
      if (cross.abs() > 0.001) {
        simplified.add(curr);
      }
    }

    simplified.add(path.last);
    return simplified;
  }

  /// Compute paths for all parking spots from entrance and to exit
  /// Returns a map of results keyed by spot ID
  Map<String, dynamic> computeAllPaths() {
    final results = <String, dynamic>{};

    if (grid.entrance == null) {
      results['error'] = 'No entrance defined';
      return results;
    }
    if (grid.exit == null) {
      results['error'] = 'No exit defined';
      return results;
    }

    final entranceCenter = grid.entrance!.center;
    final exitCenter = grid.exit!.center;

    int successCount = 0;
    int failCount = 0;
    final errors = <String>[];

    for (final spot in grid.spots) {
      // Find closest point on road near the spot (edge of spot closest to any road)
      final spotCenterX = spot.x + spot.width / 2;
      final spotCenterY = spot.y + spot.height / 2;

      // Path from entrance to spot
      final entranceToSpot = findPath(
        entranceCenter.x,
        entranceCenter.y,
        spotCenterX,
        spotCenterY,
      );

      // Path from spot to exit
      final spotToExit = findPath(
        spotCenterX,
        spotCenterY,
        exitCenter.x,
        exitCenter.y,
      );

      if (entranceToSpot.success && spotToExit.success) {
        spot.pathFromEntrance = entranceToSpot.path;
        spot.pathToExit = spotToExit.path;
        successCount++;
      } else {
        failCount++;
        if (!entranceToSpot.success) {
          errors.add('${spot.label ?? spot.id}: ${entranceToSpot.error}');
        }
        if (!spotToExit.success) {
          errors.add('${spot.label ?? spot.id}: ${spotToExit.error}');
        }
      }
    }

    results['successCount'] = successCount;
    results['failCount'] = failCount;
    results['errors'] = errors;
    results['totalSpots'] = grid.spots.length;

    return results;
  }

  /// Clear all computed paths from spots
  void clearAllPaths() {
    for (final spot in grid.spots) {
      spot.pathFromEntrance = null;
      spot.pathToExit = null;
    }
  }
}
