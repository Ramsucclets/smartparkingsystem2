import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import '../../models/parking_grid.dart';
import '../../models/parking_spot.dart';
import '../../models/road.dart';
import '../../models/obstacle.dart';
import '../../models/entrance.dart';

/// Cached grid lines image for performance
ui.Picture? _cachedGridLines;
double _cachedGridWidth = 0;
double _cachedGridHeight = 0;
double _cachedGridSize = 0;

class GridPainter extends CustomPainter {
  final ParkingGrid grid;
  final Set<String> selectedSpotIds;
  final Set<String> selectedRoadIds;
  final Set<String> selectedObstacleIds;
  final Offset? dragStart;
  final Offset? dragEnd;
  final Offset? rulerStart;
  final Offset? rulerEnd;
  final bool isHoveringRuler;
  final Offset? roadDrawStart;
  final Offset? roadDrawEnd;
  final int spotCount;
  final int roadCount;
  final int obstacleCount;
  final int repaintToken; // Token to force repaint during drag operations
  final bool showPaths; // Whether to draw computed paths

  // Pre-created Paint objects for better performance
  static final Paint _gridPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.1)
    ..strokeWidth = 1;

  static final Paint _selectionFillPaint = Paint()
    ..color = Colors.blue.withValues(alpha: 0.2)
    ..style = PaintingStyle.fill;

  static final Paint _selectionBorderPaint = Paint()
    ..color = Colors.blue.withValues(alpha: 0.5)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;

  // Static paints for path visualization
  static final Color _pathFromEntrancePaint =
      Colors.green.withValues(alpha: 0.6);
  static final Color _pathToExitPaint = Colors.red.withValues(alpha: 0.6);

  GridPainter({
    required this.grid,
    required this.selectedSpotIds,
    this.selectedRoadIds = const {},
    this.selectedObstacleIds = const {},
    this.dragStart,
    this.dragEnd,
    this.rulerStart,
    this.rulerEnd,
    this.isHoveringRuler = false,
    this.roadDrawStart,
    this.roadDrawEnd,
    this.repaintToken = 0,
    this.showPaths = false,
  })  : spotCount = grid.spots.length,
        roadCount = grid.roads.length,
        obstacleCount = grid.obstacles.length;

  /// Get or create cached grid lines picture
  ui.Picture _getGridLinesPicture() {
    if (_cachedGridLines != null &&
        _cachedGridWidth == grid.canvasWidth &&
        _cachedGridHeight == grid.canvasHeight &&
        _cachedGridSize == grid.gridSize) {
      return _cachedGridLines!;
    }

    // Create new cached picture
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    for (double x = 0; x <= grid.canvasWidth; x += grid.gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, grid.canvasHeight), _gridPaint);
    }
    for (double y = 0; y <= grid.canvasHeight; y += grid.gridSize) {
      canvas.drawLine(Offset(0, y), Offset(grid.canvasWidth, y), _gridPaint);
    }

    _cachedGridLines = recorder.endRecording();
    _cachedGridWidth = grid.canvasWidth;
    _cachedGridHeight = grid.canvasHeight;
    _cachedGridSize = grid.gridSize;

    return _cachedGridLines!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Draw cached grid lines (very fast - just replays recorded commands)
    canvas.drawPicture(_getGridLinesPicture());

    // Draw roads (behind spots)
    for (final road in grid.roads) {
      final isSelected = selectedRoadIds.contains(road.id);
      _drawRoad(canvas, road, isSelected);
    }

    // Draw obstacles (behind spots)
    for (final obstacle in grid.obstacles) {
      final isSelected = selectedObstacleIds.contains(obstacle.id);
      _drawObstacle(canvas, obstacle, isSelected);
    }

    // Draw parking spots (on top)
    for (final spot in grid.spots) {
      final isSelected = selectedSpotIds.contains(spot.id);
      _drawSpot(canvas, spot, isSelected);
    }

    // Draw road preview during drawing
    if (roadDrawStart != null && roadDrawEnd != null) {
      _drawRoadPreview(canvas, roadDrawStart!, roadDrawEnd!);
    }

    // Draw entrance and exit
    if (grid.entrance != null) {
      _drawEntrance(canvas, grid.entrance!);
    }
    if (grid.exit != null) {
      _drawExit(canvas, grid.exit!);
    }

    // Draw computed paths (optional) - uses static paints for performance
    if (showPaths) {
      for (final spot in grid.spots) {
        if (spot.pathFromEntrance != null) {
          _drawPath(canvas, spot.pathFromEntrance!, _pathFromEntrancePaint);
        }
        if (spot.pathToExit != null) {
          _drawPath(canvas, spot.pathToExit!, _pathToExitPaint);
        }
      }
    }

    // Draw drag selection rectangle (lightweight overlay)
    if (dragStart != null && dragEnd != null) {
      final selectionRect = Rect.fromPoints(dragStart!, dragEnd!);
      canvas.drawRect(selectionRect, _selectionFillPaint);
      canvas.drawRect(selectionRect, _selectionBorderPaint);
    }

    // Draw ruler measurement line
    if (rulerStart != null && rulerEnd != null) {
      _drawRuler(canvas, rulerStart!, rulerEnd!);
    }
  }

  void _drawRoad(Canvas canvas, Road road, bool isSelected) {
    final rect = Rect.fromLTWH(road.x, road.y, road.width, road.height);

    // Road fill - gray/asphalt color
    final fillPaint = Paint()
      ..color = Colors.grey.shade700
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      fillPaint,
    );

    // Center dashed line (simplified as solid)
    final centerLinePaint = Paint()
      ..color = Colors.yellow.withValues(alpha: 0.6)
      ..strokeWidth = 2;
    if (road.width > road.height) {
      // Horizontal road
      canvas.drawLine(
        Offset(road.x + 10, road.y + road.height / 2),
        Offset(road.x + road.width - 10, road.y + road.height / 2),
        centerLinePaint,
      );
    } else {
      // Vertical road
      canvas.drawLine(
        Offset(road.x + road.width / 2, road.y + 10),
        Offset(road.x + road.width / 2, road.y + road.height - 10),
        centerLinePaint,
      );
    }

    // Border
    final borderPaint = Paint()
      ..color = isSelected ? Colors.white : Colors.grey.shade500
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 3 : 1;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      borderPaint,
    );

    // Display label if set, otherwise show ID
    final displayText = road.label ?? road.id;
    final textPainter = TextPainter(
      text: TextSpan(
        text: displayText,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(road.x + 4, road.y + 4),
    );
  }

  void _drawObstacle(Canvas canvas, Obstacle obstacle, bool isSelected) {
    final rect =
        Rect.fromLTWH(obstacle.x, obstacle.y, obstacle.width, obstacle.height);
    final color = _getObstacleColor(obstacle.type);

    // Fill
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      fillPaint,
    );

    // Border
    final borderPaint = Paint()
      ..color = isSelected ? Colors.white : color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 3 : 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      borderPaint,
    );

    // Display label if set, otherwise show ID
    final displayText = obstacle.label ?? obstacle.id;
    final textPainter = TextPainter(
      text: TextSpan(
        text: displayText,
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        obstacle.x + (obstacle.width - textPainter.width) / 2,
        obstacle.y + (obstacle.height - textPainter.height) / 2,
      ),
    );
  }

  void _drawRoadPreview(Canvas canvas, Offset start, Offset end) {
    // Calculate preview rectangle
    final dx = (end.dx - start.dx).abs();
    final dy = (end.dy - start.dy).abs();
    double width, height;
    if (dx > dy) {
      width = dx;
      height = 60;
    } else {
      width = 60;
      height = dy;
    }
    final x = start.dx < end.dx ? start.dx : end.dx;
    final y = start.dy < end.dy ? start.dy : end.dy;
    final rect = Rect.fromLTWH(x, y, width, height);

    // Preview fill
    final fillPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      fillPaint,
    );

    // Preview border
    final borderPaint = Paint()
      ..color = Colors.grey
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      borderPaint,
    );
  }

  Color _getObstacleColor(ObstacleType type) {
    switch (type) {
      case ObstacleType.pillar:
        return Colors.grey.shade800;
      case ObstacleType.wall:
        return Colors.brown.shade700;
      case ObstacleType.barrier:
        return Colors.orange.shade800;
    }
  }

  void _drawRuler(Canvas canvas, Offset start, Offset end) {
    final distance = (end - start).distance;

    // Change color to red when hovering with delete tool
    final rulerColor = isHoveringRuler ? Colors.red : Colors.amber;

    // Main line
    final linePaint = Paint()
      ..color = rulerColor
      ..strokeWidth = isHoveringRuler ? 3 : 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(start, end, linePaint);

    // Start point circle
    final pointPaint = Paint()
      ..color = rulerColor
      ..style = PaintingStyle.fill;

    final pointRadius = isHoveringRuler ? 8.0 : 6.0;
    canvas.drawCircle(start, pointRadius, pointPaint);
    canvas.drawCircle(end, pointRadius, pointPaint);

    // Inner white circle
    final innerPointPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final innerRadius = isHoveringRuler ? 4.0 : 3.0;
    canvas.drawCircle(start, innerRadius, innerPointPaint);
    canvas.drawCircle(end, innerRadius, innerPointPaint);

    // Distance label background
    final midPoint = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
    final labelText = isHoveringRuler
        ? 'Click to delete'
        : '${distance.toStringAsFixed(1)} px';

    final textPainter = TextPainter(
      text: TextSpan(
        text: labelText,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Draw label background
    final labelRect = Rect.fromCenter(
      center: midPoint,
      width: textPainter.width + 12,
      height: textPainter.height + 6,
    );

    final labelBgPaint = Paint()
      ..color = rulerColor
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(4)),
      labelBgPaint,
    );

    // Draw label text
    textPainter.paint(
      canvas,
      Offset(
        midPoint.dx - textPainter.width / 2,
        midPoint.dy - textPainter.height / 2,
      ),
    );
  }

  void _drawSpot(Canvas canvas, ParkingSpot spot, bool isSelected) {
    final color = _getSpotColor(spot.type);
    final rect = Rect.fromLTWH(spot.x, spot.y, spot.width, spot.height);

    // Fill
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      fillPaint,
    );

    // Border
    final borderPaint = Paint()
      ..color = isSelected ? Colors.white : color
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 3 : 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      borderPaint,
    );

    // Display label if set, otherwise show ID
    final displayText = spot.label ?? spot.id;
    final textPainter = TextPainter(
      text: TextSpan(
        text: displayText,
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        spot.x + (spot.width - textPainter.width) / 2,
        spot.y + (spot.height - textPainter.height) / 2,
      ),
    );
  }

  Color _getSpotColor(SpotType type) {
    switch (type) {
      case SpotType.regular:
        return Colors.green;
      case SpotType.handicapped:
        return Colors.blue;
      case SpotType.evCharging:
        return Colors.orange;
    }
  }

  /// Draw entrance point with green arrow pointing inward
  void _drawEntrance(Canvas canvas, Entrance entrance) {
    final rect =
        Rect.fromLTWH(entrance.x, entrance.y, entrance.width, entrance.height);

    // Green fill
    final fillPaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      fillPaint,
    );

    // Border
    final borderPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      borderPaint,
    );

    // Draw arrow icon pointing inward (right arrow)
    final iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final centerX = entrance.x + entrance.width / 2;
    final centerY = entrance.y + entrance.height / 2;
    final arrowSize = entrance.width * 0.4;

    // Arrow pointing right (into parking)
    final path = Path()
      ..moveTo(centerX - arrowSize / 2, centerY - arrowSize / 3)
      ..lineTo(centerX + arrowSize / 2, centerY)
      ..lineTo(centerX - arrowSize / 2, centerY + arrowSize / 3)
      ..close();
    canvas.drawPath(path, iconPaint);

    // Label
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'IN',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(entrance.x + 4, entrance.y + entrance.height - 16),
    );
  }

  /// Draw exit point with red arrow pointing outward
  void _drawExit(Canvas canvas, Entrance exit) {
    final rect = Rect.fromLTWH(exit.x, exit.y, exit.width, exit.height);

    // Red fill
    final fillPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      fillPaint,
    );

    // Border
    final borderPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      borderPaint,
    );

    // Draw arrow icon pointing outward
    final iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final centerX = exit.x + exit.width / 2;
    final centerY = exit.y + exit.height / 2;
    final arrowSize = exit.width * 0.4;

    // Arrow pointing left (out of parking)
    final path = Path()
      ..moveTo(centerX + arrowSize / 2, centerY - arrowSize / 3)
      ..lineTo(centerX - arrowSize / 2, centerY)
      ..lineTo(centerX + arrowSize / 2, centerY + arrowSize / 3)
      ..close();
    canvas.drawPath(path, iconPaint);

    // Label
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'OUT',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(exit.x + 4, exit.y + exit.height - 16),
    );
  }

  /// Draw a path as a series of connected lines
  void _drawPath(Canvas canvas, List<Map<String, double>> path, Color color) {
    if (path.length < 2) return;

    final pathPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pathObj = Path();
    pathObj.moveTo(path.first['x']!, path.first['y']!);

    for (int i = 1; i < path.length; i++) {
      pathObj.lineTo(path[i]['x']!, path[i]['y']!);
    }

    canvas.drawPath(pathObj, pathPaint);

    // Draw waypoint dots
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (final point in path) {
      canvas.drawCircle(Offset(point['x']!, point['y']!), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    return repaintToken != oldDelegate.repaintToken ||
        spotCount != oldDelegate.spotCount ||
        roadCount != oldDelegate.roadCount ||
        obstacleCount != oldDelegate.obstacleCount ||
        showPaths != oldDelegate.showPaths ||
        grid.entrance != oldDelegate.grid.entrance ||
        grid.exit != oldDelegate.grid.exit ||
        !setEquals(selectedSpotIds, oldDelegate.selectedSpotIds) ||
        !setEquals(selectedRoadIds, oldDelegate.selectedRoadIds) ||
        !setEquals(selectedObstacleIds, oldDelegate.selectedObstacleIds) ||
        dragStart != oldDelegate.dragStart ||
        dragEnd != oldDelegate.dragEnd ||
        rulerStart != oldDelegate.rulerStart ||
        rulerEnd != oldDelegate.rulerEnd ||
        isHoveringRuler != oldDelegate.isHoveringRuler ||
        roadDrawStart != oldDelegate.roadDrawStart ||
        roadDrawEnd != oldDelegate.roadDrawEnd;
  }
}
