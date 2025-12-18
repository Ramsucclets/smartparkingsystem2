import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/parking_grid.dart';
import '../models/parking_spot.dart';
import '../models/road.dart';
import '../models/obstacle.dart';
import '../services/dynamodb_service.dart';
import '../widgets/navigation.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late ParkingGrid _grid;
  final TransformationController _transformController =
      TransformationController();

  // DynamoDB service for fetching real-time data
  final DynamoDBService _dynamoDBService = DynamoDBService();

  // Loading state for data fetch
  bool _isLoading = true;
  String? _errorMessage;

  // Timer for periodic refresh
  Timer? _refreshTimer;
  static const Duration _refreshInterval = Duration(seconds: 30);

  // Spot availability status (populated from backend)
  final Map<String, bool> _spotAvailability = {};

  String? _selectedSpotId;
  List<Map<String, dynamic>> _currentRoute = [];
  int _currentStepIndex = 0;

  IconData _currentIcon = Icons.info;
  String _currentDistance = "Welcome!";
  String _currentInstruction = "Please select a parking spot";

  Size? _viewportSize;

  @override
  void initState() {
    super.initState();
    _initializeGrid();
    _fetchParkingData();
    _startAutoRefresh();
    // Fit to viewport after the first frame when we have layout info
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_viewportSize != null) {
        _fitToViewport(_viewportSize!);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _transformController.dispose();
    super.dispose();
  }

  /// Start periodic refresh of parking data
  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      _fetchParkingData(showLoading: false);
    });
  }

  /// Fetch parking data from DynamoDB and update availability
  Future<void> _fetchParkingData({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final spots = await _dynamoDBService.fetchParkingSpots();

      if (mounted) {
        setState(() {
          // Update availability based on backend data
          for (final spotData in spots) {
            // Map spotId to availability (available = not occupied)
            _spotAvailability[spotData.spotId] = !spotData.isOccupied;
          }
          _isLoading = false;
          _errorMessage = null;
        });

        developer.log('Updated ${spots.length} spots from backend');
      }
    } catch (e) {
      developer.log('Error fetching parking data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  /// Fit the grid to the available viewport with padding
  void _fitToViewport(Size viewportSize) {
    if (viewportSize.isEmpty) return;

    const padding = 40.0;
    final availableWidth = viewportSize.width - padding * 2;
    final availableHeight = viewportSize.height - padding * 2;

    // Calculate scale to fit content
    final scaleX = availableWidth / _grid.canvasWidth;
    final scaleY = availableHeight / _grid.canvasHeight;
    final scale = (scaleX < scaleY ? scaleX : scaleY).clamp(0.5, 1.0);

    // Calculate translation to center the content
    final scaledWidth = _grid.canvasWidth * scale;
    final scaledHeight = _grid.canvasHeight * scale;
    final translateX = (viewportSize.width - scaledWidth) / 2;
    final translateY = (viewportSize.height - scaledHeight) / 2;

    // Apply the transform
    _transformController.value = Matrix4.identity()
      ..translate(translateX, translateY)
      ..scale(scale);
  }

  void _initializeGrid() {
    // Create a sample grid (in real app, load from JSON/backend)
    _grid = ParkingGrid.empty(name: 'Main Parking Lot');

    // Add sample spots
    final spots = [
      ParkingSpot(id: 'A1', x: 50, y: 50, type: SpotType.regular),
      ParkingSpot(id: 'A2', x: 50, y: 160, type: SpotType.regular),
      ParkingSpot(id: 'A3', x: 50, y: 270, type: SpotType.regular),
      ParkingSpot(id: 'A4', x: 50, y: 380, type: SpotType.handicapped),
      ParkingSpot(id: 'B1', x: 180, y: 50, type: SpotType.regular),
      ParkingSpot(id: 'B2', x: 180, y: 160, type: SpotType.evCharging),
      ParkingSpot(id: 'B3', x: 180, y: 270, type: SpotType.regular),
      ParkingSpot(id: 'B4', x: 180, y: 380, type: SpotType.regular),
    ];

    for (final spot in spots) {
      _grid.addSpot(spot);
      // Availability will be updated by _fetchParkingData from backend
    }
  }

  /// Upload a parking grid JSON file for testing
  Future<void> _uploadParkingGrid() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final fileBytes = result.files.first.bytes;
        if (fileBytes != null) {
          final jsonString = utf8.decode(fileBytes);
          final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

          setState(() {
            _grid = ParkingGrid.fromJson(jsonData);
            // Reset availability - will be updated from backend
            _spotAvailability.clear();
            // Reset navigation state
            _selectedSpotId = null;
            _currentRoute = [];
            _currentStepIndex = 0;
            _currentIcon = Icons.info;
            _currentDistance = "Grid Loaded!";
            _currentInstruction =
                "${_grid.name} - ${_grid.spots.length} spots, ${_grid.roads.length} roads";
          });

          // Fetch real availability from backend
          await _fetchParkingData();

          developer.log(
              'Loaded grid: ${_grid.name} with ${_grid.spots.length} spots');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('Loaded: ${_grid.name} (${_grid.spots.length} spots)'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      developer.log('Error loading grid: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading grid: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _onSpotTapped(String spotId) {
    final isAvailable = _spotAvailability[spotId] ?? false;

    if (isAvailable) {
      developer.log('Spot $spotId selected!');
      setState(() {
        _selectedSpotId = spotId;
        _startNavigationForSpot(spotId);
      });
    } else {
      developer.log('Spot $spotId is taken.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Spot $spotId is currently occupied'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _startNavigationForSpot(String spotId) {
    // Generate simple navigation route
    _currentRoute = [
      {
        'icon': Icons.straight,
        'distance': '100 m',
        'instruction': 'Go straight'
      },
      {
        'icon': Icons.turn_right,
        'distance': '50 m',
        'instruction': 'Turn right'
      },
      {
        'icon': Icons.local_parking,
        'distance': 'Arrived',
        'instruction': 'Park at spot $spotId'
      },
    ];
    _currentStepIndex = 0;
    _updateNavigationUi();
  }

  void _nextStep() {
    if (_currentRoute.isNotEmpty &&
        _currentStepIndex < _currentRoute.length - 1) {
      setState(() {
        _currentStepIndex++;
        _updateNavigationUi();
      });
    }
  }

  void _updateNavigationUi() {
    _currentIcon = _currentRoute[_currentStepIndex]['icon'];
    _currentDistance = _currentRoute[_currentStepIndex]['distance'];
    _currentInstruction = _currentRoute[_currentStepIndex]['instruction'];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_grid.name),
        actions: [
          // Loading indicator
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Parking Data',
            onPressed: _isLoading ? null : () => _fetchParkingData(),
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Upload Parking Grid JSON',
            onPressed: _uploadParkingGrid,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _currentRoute.isNotEmpty ? _nextStep : null,
        backgroundColor: _currentRoute.isNotEmpty
            ? Theme.of(context).primaryColor
            : Colors.grey,
        child: const Icon(Icons.arrow_forward),
      ),
      body: Column(
        children: [
          // Error banner
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.red.shade100,
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Failed to load parking data. Using cached data.',
                      style:
                          TextStyle(color: Colors.red.shade700, fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon:
                        Icon(Icons.close, color: Colors.red.shade700, size: 18),
                    onPressed: () => setState(() => _errorMessage = null),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          NavigationWidget(
            icon: _currentIcon,
            distance: _currentDistance,
            instruction: _currentInstruction,
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Capture viewport size and fit on first build
                    final currentSize =
                        Size(constraints.maxWidth, constraints.maxHeight);
                    if (_viewportSize == null &&
                        currentSize.width > 0 &&
                        currentSize.height > 0) {
                      _viewportSize = currentSize;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _fitToViewport(currentSize);
                      });
                    }
                    return GestureDetector(
                      onTapUp: (details) {
                        // Convert the tap position from widget-local to scene coordinates
                        final scenePos =
                            _transformController.toScene(details.localPosition);
                        _handleTap(scenePos.dx, scenePos.dy);
                      },
                      child: InteractiveViewer(
                        transformationController: _transformController,
                        constrained: false,
                        minScale: 0.5,
                        maxScale: 3.0,
                        boundaryMargin: const EdgeInsets.all(100),
                        child: Container(
                          width: _grid.canvasWidth,
                          height: _grid.canvasHeight,
                          color: Theme.of(context).scaffoldBackgroundColor,
                          child: CustomPaint(
                            size: Size(_grid.canvasWidth, _grid.canvasHeight),
                            painter: UserGridPainter(
                              grid: _grid,
                              spotAvailability: _spotAvailability,
                              selectedSpotId: _selectedSpotId,
                              isDarkMode: Theme.of(context).brightness ==
                                  Brightness.dark,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          // Legend
          _buildLegend(),
        ],
      ),
    );
  }

  void _handleTap(double x, double y) {
    // Find spot at tap position
    for (final spot in _grid.spots) {
      if (x >= spot.x &&
          x <= spot.x + spot.width &&
          y >= spot.y &&
          y <= spot.y + spot.height) {
        _onSpotTapped(spot.id);
        return;
      }
    }
  }

  Widget _buildLegend() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _legendItem(Colors.green, 'Available'),
          _legendItem(Colors.red, 'Occupied'),
          _legendItem(Colors.blue, 'Selected'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Simple painter for user-facing parking grid
class UserGridPainter extends CustomPainter {
  final ParkingGrid grid;
  final Map<String, bool> spotAvailability;
  final String? selectedSpotId;
  final bool isDarkMode;

  UserGridPainter({
    required this.grid,
    required this.spotAvailability,
    this.selectedSpotId,
    this.isDarkMode = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw grid lines
    final gridLineColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.1);
    final gridPaint = Paint()
      ..color = gridLineColor
      ..strokeWidth = 1;

    for (double x = 0; x <= grid.canvasWidth; x += grid.gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, grid.canvasHeight), gridPaint);
    }
    for (double y = 0; y <= grid.canvasHeight; y += grid.gridSize) {
      canvas.drawLine(Offset(0, y), Offset(grid.canvasWidth, y), gridPaint);
    }

    // Draw roads (behind spots)
    for (final road in grid.roads) {
      _drawRoad(canvas, road);
    }

    // Draw obstacles (behind spots)
    for (final obstacle in grid.obstacles) {
      _drawObstacle(canvas, obstacle);
    }

    // Draw parking spots
    for (final spot in grid.spots) {
      _drawSpot(canvas, spot);
    }

    // Draw entrance and exit if they exist
    if (grid.entrance != null) {
      _drawEntrance(canvas, grid.entrance!);
    }
    if (grid.exit != null) {
      _drawExit(canvas, grid.exit!);
    }
  }

  void _drawRoad(Canvas canvas, Road road) {
    final rect = Rect.fromLTWH(road.x, road.y, road.width, road.height);

    // Road fill - gray/asphalt color
    final fillPaint = Paint()
      ..color = Colors.grey.shade700
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      fillPaint,
    );

    // Center dashed line
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
      ..color = Colors.grey.shade500
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      borderPaint,
    );

    // Display label
    final displayText = road.label ?? road.id;
    final textColor = Colors.white;
    final textPainter = TextPainter(
      text: TextSpan(
        text: displayText,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.normal,
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

  void _drawObstacle(Canvas canvas, Obstacle obstacle) {
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
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      borderPaint,
    );

    // Display label
    final displayText = obstacle.label ?? obstacle.id;
    final textPainter = TextPainter(
      text: TextSpan(
        text: displayText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.normal,
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

  void _drawEntrance(Canvas canvas, dynamic entrance) {
    final rect = Rect.fromLTWH(entrance.x as double, entrance.y as double,
        entrance.width as double, entrance.height as double);

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
      Offset(
        (entrance.x as double) +
            ((entrance.width as double) - textPainter.width) / 2,
        (entrance.y as double) +
            ((entrance.height as double) - textPainter.height) / 2,
      ),
    );
  }

  void _drawExit(Canvas canvas, dynamic exit) {
    final rect = Rect.fromLTWH(exit.x as double, exit.y as double,
        exit.width as double, exit.height as double);

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
      Offset(
        (exit.x as double) + ((exit.width as double) - textPainter.width) / 2,
        (exit.y as double) + ((exit.height as double) - textPainter.height) / 2,
      ),
    );
  }

  void _drawSpot(Canvas canvas, ParkingSpot spot) {
    final isAvailable = spotAvailability[spot.id] ?? false;
    final isSelected = spot.id == selectedSpotId;

    // Determine color based on status
    Color color;
    if (isSelected) {
      color = Colors.blue;
    } else if (isAvailable) {
      color = Colors.green;
    } else {
      color = Colors.red;
    }

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
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 3 : 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      borderPaint,
    );

    // Spot type icon indicator (small colored dot in corner)
    final typeColor = _getTypeColor(spot.type);
    if (spot.type != SpotType.regular) {
      final iconPaint = Paint()
        ..color = typeColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(spot.x + spot.width - 10, spot.y + 10),
        6,
        iconPaint,
      );
    }

    // Display label if set, otherwise show ID
    final displayText = spot.label ?? spot.id;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final textPainter = TextPainter(
      text: TextSpan(
        text: displayText,
        style: TextStyle(
          color: textColor,
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

  Color _getTypeColor(SpotType type) {
    switch (type) {
      case SpotType.regular:
        return Colors.green;
      case SpotType.handicapped:
        return Colors.blue;
      case SpotType.evCharging:
        return Colors.orange;
    }
  }

  @override
  bool shouldRepaint(covariant UserGridPainter oldDelegate) {
    return selectedSpotId != oldDelegate.selectedSpotId ||
        grid.spots.length != oldDelegate.grid.spots.length ||
        grid.roads.length != oldDelegate.grid.roads.length ||
        grid.obstacles.length != oldDelegate.grid.obstacles.length ||
        grid.entrance != oldDelegate.grid.entrance ||
        grid.exit != oldDelegate.grid.exit ||
        grid.name != oldDelegate.grid.name ||
        isDarkMode != oldDelegate.isDarkMode;
  }
}
