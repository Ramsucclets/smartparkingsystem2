import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/parking_grid.dart';
import '../../models/parking_spot.dart';
import '../../models/road.dart';
import '../../models/obstacle.dart';
import '../../models/entrance.dart';
import '../../utils/pathfinder.dart';
import '../../widgets/fade_slide_transition.dart';
import 'designer_toolbar.dart';
import 'properties_panel.dart';
import 'grid_painter.dart';

import 'grid_designer_web.dart' if (dart.library.io) 'grid_designer_io.dart'
    as file_ops;

class GridDesignerScreen extends StatefulWidget {
  final String? gridId;

  const GridDesignerScreen({super.key, this.gridId});

  @override
  State<GridDesignerScreen> createState() => _GridDesignerScreenState();
}

class _GridDesignerScreenState extends State<GridDesignerScreen> {
  late ParkingGrid _grid;
  DesignerTool _currentTool = DesignerTool.select;
  SpotType _selectedSpotType = SpotType.regular;
  ObstacleType _selectedObstacleType = ObstacleType.pillar;
  EntranceType _selectedEntranceType = EntranceType.entrance;
  final Set<String> _selectedSpotIds = {};
  final Set<String> _selectedRoadIds = {};
  final Set<String> _selectedObstacleIds = {};
  bool _showPaths = false;

  Offset? _dragStart;
  Offset? _dragEnd;

  Offset? _roadDrawStart;
  Offset? _roadDrawEnd;

  final TransformationController _transformController =
      TransformationController();

  final List<String> _undoStack = [];
  final List<String> _redoStack = [];

  Offset? _rulerStart;
  Offset? _rulerEnd;
  Offset? _cursorPosition;
  bool _isHoveringRuler = false;
  String? _draggingSpotId;
  Offset? _spotDragOffset;
  String? _draggingRoadId;
  Offset? _roadDragOffset;
  String? _draggingObstacleId;
  Offset? _obstacleDragOffset;

  final ValueNotifier<int> _dragUpdateNotifier = ValueNotifier<int>(0);

  List<ParkingSpot> _clipboardSpots = [];
  List<Road> _clipboardRoads = [];
  List<Obstacle> _clipboardObstacles = [];

  Size? _canvasViewportSize;

  @override
  void initState() {
    super.initState();
    _grid = ParkingGrid.empty(name: 'New Parking Grid');
    _saveState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerCanvas();
    });
  }

  @override
  void dispose() {
    _dragUpdateNotifier.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _centerCanvas() {
    if (_canvasViewportSize == null || _canvasViewportSize!.isEmpty) {
      _transformController.value = Matrix4.identity();
      return;
    }

    final viewportWidth = _canvasViewportSize!.width;
    final viewportHeight = _canvasViewportSize!.height;

    final translateX = (viewportWidth - _grid.canvasWidth) / 2;
    final translateY = (viewportHeight - _grid.canvasHeight) / 2;

    _transformController.value = Matrix4.identity()
      ..setTranslationRaw(translateX, translateY, 0);
  }

  void _saveState() {
    _undoStack.add(_grid.toJsonString());
    _redoStack.clear();
    if (_undoStack.length > 50) {
      _undoStack.removeAt(0);
    }
  }

  void _undo() {
    if (_undoStack.length > 1) {
      setState(() {
        _redoStack.add(_undoStack.removeLast());
        _grid = ParkingGrid.fromJsonString(_undoStack.last);
        _selectedSpotIds.clear();
      });
    }
  }

  void _redo() {
    if (_redoStack.isNotEmpty) {
      setState(() {
        final state = _redoStack.removeLast();
        _undoStack.add(state);
        _grid = ParkingGrid.fromJsonString(state);
        _selectedSpotIds.clear();
      });
    }
  }

  void _addSpotAt(double x, double y) {
    final tempSpot = ParkingSpot(
      id: '',
      x: 0,
      y: 0,
      type: _selectedSpotType,
    );

    final centeredX = x - tempSpot.width / 2;
    final centeredY = y - tempSpot.height / 2;

    var snappedX = _grid.snapToGrid(centeredX);
    var snappedY = _grid.snapToGrid(centeredY);

    snappedX = snappedX.clamp(0, _grid.canvasWidth - tempSpot.width);
    snappedY = snappedY.clamp(0, _grid.canvasHeight - tempSpot.height);

    if (snappedX + tempSpot.width <= 0 ||
        snappedX >= _grid.canvasWidth ||
        snappedY + tempSpot.height <= 0 ||
        snappedY >= _grid.canvasHeight) {
      return;
    }

    final spot = ParkingSpot(
      id: _grid.generateSpotId(),
      x: snappedX,
      y: snappedY,
      type: _selectedSpotType,
    );

    setState(() {
      _grid.addSpot(spot);
      _selectedSpotIds.clear();
      _selectedSpotIds.add(spot.id);
    });
    _saveState();
  }

  String? _findSpotAt(double x, double y) {
    for (int i = _grid.spots.length - 1; i >= 0; i--) {
      final spot = _grid.spots[i];
      if (x >= spot.x &&
          x <= spot.x + spot.width &&
          y >= spot.y &&
          y <= spot.y + spot.height) {
        return spot.id;
      }
    }
    return null;
  }

  String? _findRoadAt(double x, double y) {
    for (int i = _grid.roads.length - 1; i >= 0; i--) {
      final road = _grid.roads[i];
      if (x >= road.x &&
          x <= road.x + road.width &&
          y >= road.y &&
          y <= road.y + road.height) {
        return road.id;
      }
    }
    return null;
  }

  String? _findObstacleAt(double x, double y) {
    for (int i = _grid.obstacles.length - 1; i >= 0; i--) {
      final obstacle = _grid.obstacles[i];
      if (x >= obstacle.x &&
          x <= obstacle.x + obstacle.width &&
          y >= obstacle.y &&
          y <= obstacle.y + obstacle.height) {
        return obstacle.id;
      }
    }
    return null;
  }

  void _addRoadAt(double x, double y, {double? endX, double? endY}) {
    double roadWidth = 80;
    double roadHeight = 200;

    if (endX != null && endY != null) {
      final dx = (endX - x).abs();
      final dy = (endY - y).abs();
      if (dx > dy) {
        roadWidth = dx.clamp(40, _grid.canvasWidth);
        roadHeight = 60;
      } else {
        roadWidth = 60;
        roadHeight = dy.clamp(40, _grid.canvasHeight);
      }
      x = x < endX ? x : endX;
      y = y < endY ? y : endY;
    }

    var snappedX = _grid.snapToGrid(x);
    var snappedY = _grid.snapToGrid(y);

    snappedX = snappedX.clamp(0, _grid.canvasWidth - roadWidth);
    snappedY = snappedY.clamp(0, _grid.canvasHeight - roadHeight);

    final road = Road(
      id: _grid.generateRoadId(),
      x: snappedX,
      y: snappedY,
      width: roadWidth,
      height: roadHeight,
    );

    setState(() {
      _grid.addRoad(road);
      _selectedRoadIds.clear();
      _selectedRoadIds.add(road.id);
      _selectedSpotIds.clear();
      _selectedObstacleIds.clear();
    });
    _saveState();
  }

  void _addObstacleAt(double x, double y) {
    final tempObstacle = Obstacle(
      id: '',
      x: 0,
      y: 0,
      type: _selectedObstacleType,
    );

    final centeredX = x - tempObstacle.width / 2;
    final centeredY = y - tempObstacle.height / 2;

    var snappedX = _grid.snapToGrid(centeredX);
    var snappedY = _grid.snapToGrid(centeredY);

    snappedX = snappedX.clamp(0, _grid.canvasWidth - tempObstacle.width);
    snappedY = snappedY.clamp(0, _grid.canvasHeight - tempObstacle.height);

    final obstacle = Obstacle(
      id: _grid.generateObstacleId(),
      x: snappedX,
      y: snappedY,
      type: _selectedObstacleType,
    );

    setState(() {
      _grid.addObstacle(obstacle);
      _selectedObstacleIds.clear();
      _selectedObstacleIds.add(obstacle.id);
      _selectedSpotIds.clear();
      _selectedRoadIds.clear();
    });
    _saveState();
  }

  void _addEntranceAt(double x, double y) {
    final road = _grid.findRoadAtPoint(x, y);
    if (road == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entrance/Exit must be placed on a road'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final tempEntrance = Entrance(
      id: '',
      x: 0,
      y: 0,
      type: _selectedEntranceType,
    );

    final centeredX = x - tempEntrance.width / 2;
    final centeredY = y - tempEntrance.height / 2;

    var snappedX = _grid.snapToGrid(centeredX);
    var snappedY = _grid.snapToGrid(centeredY);

    snappedX = snappedX.clamp(0, _grid.canvasWidth - tempEntrance.width);
    snappedY = snappedY.clamp(0, _grid.canvasHeight - tempEntrance.height);

    final entrance = Entrance(
      id: _selectedEntranceType == EntranceType.entrance ? 'ENTRANCE' : 'EXIT',
      x: snappedX,
      y: snappedY,
      type: _selectedEntranceType,
      attachedRoadId: road.id,
    );

    setState(() {
      if (_selectedEntranceType == EntranceType.entrance) {
        _grid.setEntrance(entrance);
      } else {
        _grid.setExit(entrance);
      }
    });
    _saveState();

    final typeLabel =
        _selectedEntranceType == EntranceType.entrance ? 'Entrance' : 'Exit';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$typeLabel placed successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _computeRoutes() {
    if (_grid.entrance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please place an entrance first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_grid.exit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please place an exit first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_grid.spots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No parking spots to compute routes for'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final pathFinder = PathFinder(_grid, cellSize: _grid.gridSize);
    final results = pathFinder.computeAllPaths();

    if (results.containsKey('error')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${results['error']}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final successCount = results['successCount'] as int;
    final failCount = results['failCount'] as int;
    final errors = results['errors'] as List<String>;

    setState(() {
      _showPaths = true; // Show computed paths
    });
    _saveState();

    if (failCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully computed routes for $successCount spots'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Computed $successCount routes, $failCount failed'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Details',
            textColor: Colors.white,
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Routing Errors'),
                  content: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: errors.map((e) => Text('• $e')).toList(),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }
  }

  void _selectElementAt(double x, double y) {
    final spotId = _findSpotAt(x, y);
    if (spotId != null) {
      setState(() {
        _clearAllSelections();
        _selectedSpotIds.add(spotId);
      });
      return;
    }

    final roadId = _findRoadAt(x, y);
    if (roadId != null) {
      setState(() {
        _clearAllSelections();
        _selectedRoadIds.add(roadId);
      });
      return;
    }

    final obstacleId = _findObstacleAt(x, y);
    if (obstacleId != null) {
      setState(() {
        _clearAllSelections();
        _selectedObstacleIds.add(obstacleId);
      });
      return;
    }

    setState(() {
      _clearAllSelections();
    });
  }

  void _deleteSpotAt(double x, double y) {
    final foundId = _findSpotAt(x, y);
    if (foundId != null) {
      final index = _grid.spots.indexWhere((s) => s.id == foundId);
      if (index != -1) {
        setState(() {
          _grid.spots.removeAt(index);
          _selectedSpotIds.remove(foundId);
        });
        _saveState();
        return;
      }
    }
    final roadId = _findRoadAt(x, y);
    if (roadId != null) {
      _deleteRoadAt(roadId);
      return;
    }

    final obstacleId = _findObstacleAt(x, y);
    if (obstacleId != null) {
      _deleteObstacleAt(obstacleId);
    }
  }

  void _deleteRoadAt(String roadId) {
    final index = _grid.roads.indexWhere((r) => r.id == roadId);
    if (index != -1) {
      setState(() {
        _grid.roads.removeAt(index);
        _selectedRoadIds.remove(roadId);
      });
      _saveState();
    }
  }

  void _deleteObstacleAt(String obstacleId) {
    final index = _grid.obstacles.indexWhere((o) => o.id == obstacleId);
    if (index != -1) {
      setState(() {
        _grid.obstacles.removeAt(index);
        _selectedObstacleIds.remove(obstacleId);
      });
      _saveState();
    }
  }

  void _deleteSelectedSpot() {
    if (_selectedSpotIds.isNotEmpty) {
      setState(() {
        _grid.spots.removeWhere((s) => _selectedSpotIds.contains(s.id));
        _selectedSpotIds.clear();
      });
      _saveState();
    }
  }

  void _deleteSelectedRoads() {
    if (_selectedRoadIds.isNotEmpty) {
      setState(() {
        _grid.roads.removeWhere((r) => _selectedRoadIds.contains(r.id));
        _selectedRoadIds.clear();
      });
      _saveState();
    }
  }

  void _deleteSelectedObstacles() {
    if (_selectedObstacleIds.isNotEmpty) {
      setState(() {
        _grid.obstacles.removeWhere((o) => _selectedObstacleIds.contains(o.id));
        _selectedObstacleIds.clear();
      });
      _saveState();
    }
  }

  void _deleteAllSelected() {
    setState(() {
      _grid.spots.removeWhere((s) => _selectedSpotIds.contains(s.id));
      _grid.roads.removeWhere((r) => _selectedRoadIds.contains(r.id));
      _grid.obstacles.removeWhere((o) => _selectedObstacleIds.contains(o.id));
      _clearAllSelections();
    });
    _saveState();
  }

  void _clearAllSelections() {
    _selectedSpotIds.clear();
    _selectedRoadIds.clear();
    _selectedObstacleIds.clear();
  }

  void _copySelected() {
    _clipboardSpots = _grid.spots
        .where((s) => _selectedSpotIds.contains(s.id))
        .map((s) => ParkingSpot(
              id: s.id,
              x: s.x,
              y: s.y,
              width: s.width,
              height: s.height,
              rotation: s.rotation,
              type: s.type,
              label: s.label,
            ))
        .toList();

    _clipboardRoads = _grid.roads
        .where((r) => _selectedRoadIds.contains(r.id))
        .map((r) => Road(
              id: r.id,
              x: r.x,
              y: r.y,
              width: r.width,
              height: r.height,
            ))
        .toList();

    _clipboardObstacles = _grid.obstacles
        .where((o) => _selectedObstacleIds.contains(o.id))
        .map((o) => Obstacle(
              id: o.id,
              x: o.x,
              y: o.y,
              width: o.width,
              height: o.height,
              type: o.type,
            ))
        .toList();

    if (_clipboardSpots.isNotEmpty ||
        _clipboardRoads.isNotEmpty ||
        _clipboardObstacles.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Copied ${_clipboardSpots.length} spots, ${_clipboardRoads.length} roads, ${_clipboardObstacles.length} obstacles'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _pasteFromClipboard() {
    if (_clipboardSpots.isEmpty &&
        _clipboardRoads.isEmpty &&
        _clipboardObstacles.isEmpty) {
      return;
    }

    const pasteOffset = 20.0;

    setState(() {
      _clearAllSelections();

      for (final spot in _clipboardSpots) {
        final newSpot = ParkingSpot(
          id: _grid.generateSpotId(),
          x: (spot.x + pasteOffset).clamp(0, _grid.canvasWidth - spot.width),
          y: (spot.y + pasteOffset).clamp(0, _grid.canvasHeight - spot.height),
          width: spot.width,
          height: spot.height,
          rotation: spot.rotation,
          type: spot.type,
          label: spot.label,
        );
        _grid.addSpot(newSpot);
        _selectedSpotIds.add(newSpot.id);
      }

      for (final road in _clipboardRoads) {
        final newRoad = Road(
          id: _grid.generateRoadId(),
          x: (road.x + pasteOffset).clamp(0, _grid.canvasWidth - road.width),
          y: (road.y + pasteOffset).clamp(0, _grid.canvasHeight - road.height),
          width: road.width,
          height: road.height,
        );
        _grid.addRoad(newRoad);
        _selectedRoadIds.add(newRoad.id);
      }

      for (final obstacle in _clipboardObstacles) {
        final newObstacle = Obstacle(
          id: _grid.generateObstacleId(),
          x: (obstacle.x + pasteOffset)
              .clamp(0, _grid.canvasWidth - obstacle.width),
          y: (obstacle.y + pasteOffset)
              .clamp(0, _grid.canvasHeight - obstacle.height),
          width: obstacle.width,
          height: obstacle.height,
          type: obstacle.type,
        );
        _grid.addObstacle(newObstacle);
        _selectedObstacleIds.add(newObstacle.id);
      }
    });

    _saveState();
  }

  void _selectAll() {
    setState(() {
      _selectedSpotIds.clear();
      _selectedRoadIds.clear();
      _selectedObstacleIds.clear();

      for (final spot in _grid.spots) {
        _selectedSpotIds.add(spot.id);
      }
      for (final road in _grid.roads) {
        _selectedRoadIds.add(road.id);
      }
      for (final obstacle in _grid.obstacles) {
        _selectedObstacleIds.add(obstacle.id);
      }
    });
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Elements?'),
        content: const Text(
            'This will remove all spots, roads, and obstacles from the grid.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _grid.spots.clear();
                _grid.roads.clear();
                _grid.obstacles.clear();
                _selectedSpotIds.clear();
                _selectedRoadIds.clear();
                _selectedObstacleIds.clear();
              });
              _saveState();
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToJson() async {
    final jsonString = _grid.toJsonString();
    final fileName = '${_grid.name.replaceAll(' ', '_')}.json';

    if (kIsWeb) {
      file_ops.downloadFileWeb(jsonString, fileName);
    } else {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Parking Grid',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result != null) {
        file_ops.saveFileDesktop(result, jsonString);
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Grid exported successfully!')),
      );
    }
  }

  Future<void> _importFromJson() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      try {
        final jsonString = utf8.decode(result.files.single.bytes!);
        final importedGrid = ParkingGrid.fromJsonString(jsonString);

        setState(() {
          _grid = importedGrid;
          _selectedSpotIds.clear();
        });
        _saveState();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Loaded: ${_grid.name}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading file: $e')),
          );
        }
      }
    }
  }

  void _showRenameDialog() {
    final controller = TextEditingController(text: _grid.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Grid'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Grid Name',
            hintText: 'Enter grid name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              setState(() => _grid.name = value.trim());
              _saveState();
            }
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() => _grid.name = controller.text.trim());
                _saveState();
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;

          if (isCtrlPressed && event.logicalKey == LogicalKeyboardKey.keyZ) {
            if (_undoStack.length > 1) {
              _undo();
              return KeyEventResult.handled;
            }
          } else if (isCtrlPressed &&
              event.logicalKey == LogicalKeyboardKey.keyY) {
            if (_redoStack.isNotEmpty) {
              _redo();
              return KeyEventResult.handled;
            }
          } else if (isCtrlPressed &&
              event.logicalKey == LogicalKeyboardKey.keyC) {
            _copySelected();
            return KeyEventResult.handled;
          } else if (isCtrlPressed &&
              event.logicalKey == LogicalKeyboardKey.keyV) {
            _pasteFromClipboard();
            return KeyEventResult.handled;
          } else if (isCtrlPressed &&
              event.logicalKey == LogicalKeyboardKey.keyS) {
            _exportToJson();
            return KeyEventResult.handled;
          } else if (isCtrlPressed &&
              event.logicalKey == LogicalKeyboardKey.keyA) {
            _selectAll();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            if (_rulerStart != null || _rulerEnd != null) {
              _clearRuler();
              return KeyEventResult.handled;
            } else if (_selectedSpotIds.isNotEmpty ||
                _selectedRoadIds.isNotEmpty ||
                _selectedObstacleIds.isNotEmpty) {
              setState(() => _clearAllSelections());
              return KeyEventResult.handled;
            }
          } else if (event.logicalKey == LogicalKeyboardKey.delete) {
            if (_selectedSpotIds.isNotEmpty) {
              _deleteSelectedSpot();
              return KeyEventResult.handled;
            }
          } else if (event.logicalKey == LogicalKeyboardKey.keyR) {
            if (_selectedSpotIds.isNotEmpty) {
              _rotateSelectedSpots();
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        appBar: AppBar(
          title: InkWell(
            onTap: _showRenameDialog,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_grid.name),
                  const SizedBox(width: 8),
                  Icon(Icons.edit, size: 16, color: Colors.white70),
                ],
              ),
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.undo),
              onPressed: _undoStack.length > 1 ? _undo : null,
              tooltip: 'Undo (Ctrl+Z)',
            ),
            IconButton(
              icon: const Icon(Icons.redo),
              onPressed: _redoStack.isNotEmpty ? _redo : null,
              tooltip: 'Redo (Ctrl+Y)',
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.route),
              onPressed: _computeRoutes,
              tooltip: 'Compute Routes',
            ),
            IconButton(
              icon: Icon(_showPaths ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _showPaths = !_showPaths),
              tooltip: _showPaths ? 'Hide Paths' : 'Show Paths',
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.file_upload),
              onPressed: _importFromJson,
              tooltip: 'Import JSON',
            ),
            IconButton(
              icon: const Icon(Icons.file_download),
              onPressed: _exportToJson,
              tooltip: 'Export JSON',
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Row(
          children: [
            // Left toolbar
            FadeSlideTransition(
              index: 0,
              child: DesignerToolbar(
                currentTool: _currentTool,
                selectedSpotType: _selectedSpotType,
                selectedObstacleType: _selectedObstacleType,
                selectedEntranceType: _selectedEntranceType,
                onToolChanged: (tool) => setState(() => _currentTool = tool),
                onSpotTypeChanged: (type) =>
                    setState(() => _selectedSpotType = type),
                onObstacleTypeChanged: (type) =>
                    setState(() => _selectedObstacleType = type),
                onEntranceTypeChanged: (type) =>
                    setState(() => _selectedEntranceType = type),
                onClearAll: _clearAll,
              ),
            ),
            // Main canvas
            Expanded(
              child: FadeSlideTransition(
                index: 1,
                child: _buildCanvas(),
              ),
            ),
            // Right properties panel
            if (_selectedSpotIds.isNotEmpty ||
                _selectedRoadIds.isNotEmpty ||
                _selectedObstacleIds.isNotEmpty)
              RepaintBoundary(
                child: FadeSlideTransition(
                  index: 2,
                  child: PropertiesPanel(
                    selectedSpotIds: _selectedSpotIds,
                    selectedRoadIds: _selectedRoadIds,
                    selectedObstacleIds: _selectedObstacleIds,
                    grid: _grid,
                    onDeleteSelected: _deleteAllSelected,
                    onRotateSelected: _rotateSelectedSpots,
                    onRotateSpot: _rotateSpot,
                    onDeleteRoads: _deleteSelectedRoads,
                    onDeleteObstacles: _deleteSelectedObstacles,
                    onStateChanged: () {
                      setState(() {});
                      _saveState();
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final currentSize =
                      Size(constraints.maxWidth, constraints.maxHeight);
                  if (_canvasViewportSize == null &&
                      currentSize.width > 0 &&
                      currentSize.height > 0) {
                    _canvasViewportSize = currentSize;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _centerCanvas();
                    });
                  }
                  return MouseRegion(
                    onHover: (event) {
                      final localPosition =
                          _transformController.toScene(event.localPosition);
                      // Update values without setState - use notifier for canvas updates only
                      _cursorPosition = localPosition;
                      final wasHovering = _isHoveringRuler;
                      _isHoveringRuler = _currentTool == DesignerTool.delete &&
                          _isNearRuler(localPosition.dx, localPosition.dy);
                      // Only trigger repaint if hover state changed
                      if (wasHovering != _isHoveringRuler) {
                        _dragUpdateNotifier.value++;
                      }
                    },
                    onExit: (_) {
                      _cursorPosition = null;
                      if (_isHoveringRuler) {
                        _isHoveringRuler = false;
                        _dragUpdateNotifier.value++;
                      }
                    },
                    child: Listener(
                      onPointerDown: (event) {
                        final localPosition =
                            _transformController.toScene(event.localPosition);
                        if (_currentTool == DesignerTool.select) {
                          final spotId =
                              _findSpotAt(localPosition.dx, localPosition.dy);
                          if (spotId != null) {
                            final spot = _grid.findSpot(spotId);
                            if (spot != null) {
                              setState(() {
                                _draggingSpotId = spotId;
                                // Calculate offset from spot origin to click point
                                _spotDragOffset = Offset(
                                  localPosition.dx - spot.x,
                                  localPosition.dy - spot.y,
                                );
                                // Auto-select the spot being dragged
                                if (!_selectedSpotIds.contains(spotId)) {
                                  _clearAllSelections();
                                  _selectedSpotIds.add(spotId);
                                }
                              });
                            }
                          } else {
                            final roadId =
                                _findRoadAt(localPosition.dx, localPosition.dy);
                            if (roadId != null) {
                              final road = _grid.findRoad(roadId);
                              if (road != null) {
                                setState(() {
                                  _draggingRoadId = roadId;
                                  _roadDragOffset = Offset(
                                    localPosition.dx - road.x,
                                    localPosition.dy - road.y,
                                  );
                                  if (!_selectedRoadIds.contains(roadId)) {
                                    _clearAllSelections();
                                    _selectedRoadIds.add(roadId);
                                  }
                                });
                              }
                            } else {
                              final obstacleId = _findObstacleAt(
                                  localPosition.dx, localPosition.dy);
                              if (obstacleId != null) {
                                final obstacle = _grid.findObstacle(obstacleId);
                                if (obstacle != null) {
                                  setState(() {
                                    _draggingObstacleId = obstacleId;
                                    _obstacleDragOffset = Offset(
                                      localPosition.dx - obstacle.x,
                                      localPosition.dy - obstacle.y,
                                    );
                                    if (!_selectedObstacleIds
                                        .contains(obstacleId)) {
                                      _clearAllSelections();
                                      _selectedObstacleIds.add(obstacleId);
                                    }
                                  });
                                }
                              } else {
                                // Start box selection on empty area
                                setState(() {
                                  _dragStart = localPosition;
                                  _dragEnd = localPosition;
                                });
                              }
                            }
                          }
                        } else if (_currentTool == DesignerTool.addSpot) {
                          _addSpotAt(localPosition.dx, localPosition.dy);
                        } else if (_currentTool == DesignerTool.delete) {
                          if (_isNearRuler(
                              localPosition.dx, localPosition.dy)) {
                            _clearRuler();
                          } else {
                            _deleteSpotAt(localPosition.dx, localPosition.dy);
                          }
                        } else if (_currentTool == DesignerTool.ruler) {
                          setState(() {
                            _rulerStart = localPosition;
                            _rulerEnd = localPosition;
                          });
                        } else if (_currentTool == DesignerTool.rotate) {
                          final spotId =
                              _findSpotAt(localPosition.dx, localPosition.dy);
                          if (spotId != null) {
                            _rotateSpot(spotId);
                          }
                        } else if (_currentTool == DesignerTool.addRoad) {
                          setState(() {
                            _roadDrawStart = localPosition;
                            _roadDrawEnd = localPosition;
                          });
                        } else if (_currentTool == DesignerTool.addObstacle) {
                          _addObstacleAt(localPosition.dx, localPosition.dy);
                        } else if (_currentTool == DesignerTool.addEntrance) {
                          _addEntranceAt(localPosition.dx, localPosition.dy);
                        }
                      },
                      onPointerMove: (event) {
                        final localPosition =
                            _transformController.toScene(event.localPosition);
                        if (_currentTool == DesignerTool.select) {
                          if (_draggingSpotId != null &&
                              _spotDragOffset != null) {
                            final spot = _grid.findSpot(_draggingSpotId!);
                            if (spot != null) {
                              final newX =
                                  localPosition.dx - _spotDragOffset!.dx;
                              final newY =
                                  localPosition.dy - _spotDragOffset!.dy;
                              spot.x = _grid
                                  .snapToGrid(newX)
                                  .clamp(0, _grid.canvasWidth - spot.width);
                              spot.y = _grid
                                  .snapToGrid(newY)
                                  .clamp(0, _grid.canvasHeight - spot.height);
                              _dragUpdateNotifier.value++;
                            }
                          } else if (_draggingRoadId != null &&
                              _roadDragOffset != null) {
                            final road = _grid.findRoad(_draggingRoadId!);
                            if (road != null) {
                              final newX =
                                  localPosition.dx - _roadDragOffset!.dx;
                              final newY =
                                  localPosition.dy - _roadDragOffset!.dy;
                              road.x = _grid
                                  .snapToGrid(newX)
                                  .clamp(0, _grid.canvasWidth - road.width);
                              road.y = _grid
                                  .snapToGrid(newY)
                                  .clamp(0, _grid.canvasHeight - road.height);
                              _dragUpdateNotifier.value++;
                            }
                          } else if (_draggingObstacleId != null &&
                              _obstacleDragOffset != null) {
                            final obstacle =
                                _grid.findObstacle(_draggingObstacleId!);
                            if (obstacle != null) {
                              final newX =
                                  localPosition.dx - _obstacleDragOffset!.dx;
                              final newY =
                                  localPosition.dy - _obstacleDragOffset!.dy;
                              obstacle.x = _grid
                                  .snapToGrid(newX)
                                  .clamp(0, _grid.canvasWidth - obstacle.width);
                              obstacle.y = _grid.snapToGrid(newY).clamp(
                                  0, _grid.canvasHeight - obstacle.height);
                              _dragUpdateNotifier.value++;
                            }
                          } else if (_dragStart != null) {
                            _dragEnd = localPosition;
                            _dragUpdateNotifier.value++;
                          }
                        } else if (_currentTool == DesignerTool.ruler &&
                            _rulerStart != null) {
                          _rulerEnd = localPosition;
                          _dragUpdateNotifier.value++;
                        } else if (_currentTool == DesignerTool.addRoad &&
                            _roadDrawStart != null) {
                          _roadDrawEnd = localPosition;
                          _dragUpdateNotifier.value++;
                        }
                      },
                      onPointerUp: (event) {
                        if (_currentTool == DesignerTool.select) {
                          if (_draggingSpotId != null) {
                            setState(() {
                              _draggingSpotId = null;
                              _spotDragOffset = null;
                            });
                            _saveState();
                          } else if (_draggingRoadId != null) {
                            setState(() {
                              _draggingRoadId = null;
                              _roadDragOffset = null;
                            });
                            _saveState();
                          } else if (_draggingObstacleId != null) {
                            setState(() {
                              _draggingObstacleId = null;
                              _obstacleDragOffset = null;
                            });
                            _saveState();
                          } else if (_dragStart != null) {
                            final localPosition = _transformController
                                .toScene(event.localPosition);
                            final dragDistance =
                                (_dragStart! - localPosition).distance;
                            if (dragDistance < 5) {
                              _selectElementAt(
                                  localPosition.dx, localPosition.dy);
                            } else {
                              _updateSelectionFromDrag();
                            }
                            setState(() {
                              _dragStart = null;
                              _dragEnd = null;
                            });
                          }
                        } else if (_currentTool == DesignerTool.addRoad &&
                            _roadDrawStart != null) {
                          final localPosition =
                              _transformController.toScene(event.localPosition);
                          final dragDistance =
                              (_roadDrawStart! - localPosition).distance;
                          if (dragDistance > 20) {
                            _addRoadAt(
                              _roadDrawStart!.dx,
                              _roadDrawStart!.dy,
                              endX: localPosition.dx,
                              endY: localPosition.dy,
                            );
                          } else {
                            _addRoadAt(localPosition.dx, localPosition.dy);
                          }
                          setState(() {
                            _roadDrawStart = null;
                            _roadDrawEnd = null;
                          });
                        }
                      },
                      child: InteractiveViewer(
                        transformationController: _transformController,
                        panEnabled: _currentTool == DesignerTool.pan,
                        scaleEnabled: _currentTool == DesignerTool.pan,
                        constrained: false,
                        minScale: 0.5,
                        maxScale: 3.0,
                        boundaryMargin: const EdgeInsets.all(500),
                        child: Center(
                          child: Container(
                            width: _grid.canvasWidth,
                            height: _grid.canvasHeight,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D0D1A),
                              border: Border.all(
                                color: Colors.white24,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: ValueListenableBuilder<int>(
                              valueListenable: _dragUpdateNotifier,
                              builder: (context, _, __) {
                                return RepaintBoundary(
                                  child: CustomPaint(
                                    size: Size(
                                        _grid.canvasWidth, _grid.canvasHeight),
                                    painter: GridPainter(
                                      grid: _grid,
                                      selectedSpotIds: _selectedSpotIds,
                                      selectedRoadIds: _selectedRoadIds,
                                      selectedObstacleIds: _selectedObstacleIds,
                                      dragStart: _dragStart,
                                      dragEnd: _dragEnd,
                                      rulerStart: _rulerStart,
                                      rulerEnd: _rulerEnd,
                                      isHoveringRuler: _isHoveringRuler,
                                      roadDrawStart: _roadDrawStart,
                                      roadDrawEnd: _roadDrawEnd,
                                      repaintToken: _dragUpdateNotifier.value,
                                      showPaths: _showPaths,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          _buildInfoBar(),
        ],
      ),
    );
  }

  bool _isNearRuler(double x, double y) {
    if (_rulerStart == null || _rulerEnd == null) return false;

    final clickPoint = Offset(x, y);
    const hitRadius = 15.0;

    if ((clickPoint - _rulerStart!).distance <= hitRadius) {
      return true;
    }
    if ((clickPoint - _rulerEnd!).distance <= hitRadius) {
      return true;
    }

    final lineLength = (_rulerEnd! - _rulerStart!).distance;
    if (lineLength < 0.001) return false;

    final dx = _rulerEnd!.dx - _rulerStart!.dx;
    final dy = _rulerEnd!.dy - _rulerStart!.dy;

    final t = ((x - _rulerStart!.dx) * dx + (y - _rulerStart!.dy) * dy) /
        (lineLength * lineLength);

    final tClamped = t.clamp(0.0, 1.0);

    final closestX = _rulerStart!.dx + tClamped * dx;
    final closestY = _rulerStart!.dy + tClamped * dy;
    final closestPoint = Offset(closestX, closestY);

    return (clickPoint - closestPoint).distance <= hitRadius;
  }

  void _clearRuler() {
    setState(() {
      _rulerStart = null;
      _rulerEnd = null;
    });
  }

  void _rotateSpot(String spotId) {
    final spot = _grid.findSpot(spotId);
    if (spot != null) {
      setState(() {
        spot.rotation = (spot.rotation + 90) % 360;
        final oldWidth = spot.width;
        spot.width = spot.height;
        spot.height = oldWidth;
        _selectedSpotIds.clear();
        _selectedSpotIds.add(spotId);
      });
      _saveState();
    }
  }

  void _rotateSelectedSpots() {
    if (_selectedSpotIds.isEmpty) return;
    setState(() {
      for (final spotId in _selectedSpotIds) {
        final spot = _grid.findSpot(spotId);
        if (spot != null) {
          spot.rotation = (spot.rotation + 90) % 360;
          final oldWidth = spot.width;
          spot.width = spot.height;
          spot.height = oldWidth;
        }
      }
    });
    _saveState();
  }

  Widget _buildInfoBar() {
    final rulerDistance = (_rulerStart != null && _rulerEnd != null)
        ? (_rulerEnd! - _rulerStart!).distance
        : null;

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        children: [
          // Canvas dimensions
          Icon(Icons.crop_square, size: 14, color: Colors.white54),
          const SizedBox(width: 4),
          Text(
            '${_grid.canvasWidth.toInt()} × ${_grid.canvasHeight.toInt()} px',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(width: 16),
          // Grid size
          Icon(Icons.grid_4x4, size: 14, color: Colors.white54),
          const SizedBox(width: 4),
          Text(
            '${_grid.gridSize.toInt()} px',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const Spacer(),
          // Cursor position
          if (_cursorPosition != null) ...[
            Icon(Icons.my_location, size: 14, color: Colors.white54),
            const SizedBox(width: 4),
            Text(
              '${_cursorPosition!.dx.toInt()}, ${_cursorPosition!.dy.toInt()}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(width: 16),
          ],
          if (rulerDistance != null) ...[
            Icon(Icons.straighten, size: 14, color: Colors.amber),
            const SizedBox(width: 4),
            Text(
              '${rulerDistance.toStringAsFixed(1)} px',
              style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _clearRuler,
              borderRadius: BorderRadius.circular(4),
              child: Tooltip(
                message: 'Clear Ruler (Esc)',
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.amber,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _updateSelectionFromDrag() {
    if (_dragStart == null || _dragEnd == null) return;

    final rect = Rect.fromPoints(_dragStart!, _dragEnd!);
    final newSpotSelection = <String>{};
    final newRoadSelection = <String>{};
    final newObstacleSelection = <String>{};

    for (final spot in _grid.spots) {
      final spotRect = Rect.fromLTWH(spot.x, spot.y, spot.width, spot.height);
      if (rect.overlaps(spotRect)) {
        newSpotSelection.add(spot.id);
      }
    }

    for (final road in _grid.roads) {
      final roadRect = Rect.fromLTWH(road.x, road.y, road.width, road.height);
      if (rect.overlaps(roadRect)) {
        newRoadSelection.add(road.id);
      }
    }

    for (final obstacle in _grid.obstacles) {
      final obstacleRect = Rect.fromLTWH(
          obstacle.x, obstacle.y, obstacle.width, obstacle.height);
      if (rect.overlaps(obstacleRect)) {
        newObstacleSelection.add(obstacle.id);
      }
    }

    setState(() {
      _clearAllSelections();
      _selectedSpotIds.addAll(newSpotSelection);
      _selectedRoadIds.addAll(newRoadSelection);
      _selectedObstacleIds.addAll(newObstacleSelection);
    });
  }
}
