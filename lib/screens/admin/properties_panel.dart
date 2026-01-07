import 'package:flutter/material.dart';
import '../../models/parking_spot.dart';
import '../../models/parking_grid.dart';
import '../../models/road.dart';
import '../../models/obstacle.dart';

typedef SpotUpdateCallback = void Function(ParkingSpot spot);
typedef VoidCallback = void Function();
typedef RotateSpotCallback = void Function(String spotId);

class PropertiesPanel extends StatelessWidget {
  final Set<String> selectedSpotIds;
  final Set<String> selectedRoadIds;
  final Set<String> selectedObstacleIds;
  final ParkingGrid grid;
  final VoidCallback onDeleteSelected;
  final VoidCallback onRotateSelected;
  final RotateSpotCallback onRotateSpot;
  final VoidCallback onStateChanged;
  final VoidCallback? onDeleteRoads;
  final VoidCallback? onDeleteObstacles;

  const PropertiesPanel({
    super.key,
    required this.selectedSpotIds,
    this.selectedRoadIds = const {},
    this.selectedObstacleIds = const {},
    required this.grid,
    required this.onDeleteSelected,
    required this.onRotateSelected,
    required this.onRotateSpot,
    required this.onStateChanged,
    this.onDeleteRoads,
    this.onDeleteObstacles,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedSpotIds.isEmpty &&
        selectedRoadIds.isEmpty &&
        selectedObstacleIds.isEmpty) {
      return const SizedBox.shrink();
    }

    if (selectedSpotIds.isNotEmpty &&
        selectedRoadIds.isEmpty &&
        selectedObstacleIds.isEmpty) {
      if (selectedSpotIds.length == 1) {
        final spot = grid.findSpot(selectedSpotIds.first);
        if (spot == null) return const SizedBox.shrink();
        return _buildSingleSpotProperties(context, spot);
      }
      return _buildMultiSpotProperties(context);
    }

    if (selectedRoadIds.isNotEmpty &&
        selectedSpotIds.isEmpty &&
        selectedObstacleIds.isEmpty) {
      if (selectedRoadIds.length == 1) {
        final road = grid.findRoad(selectedRoadIds.first);
        if (road == null) return const SizedBox.shrink();
        return _buildSingleRoadProperties(context, road);
      }
      return _buildMultiRoadProperties(context);
    }

    if (selectedObstacleIds.isNotEmpty &&
        selectedSpotIds.isEmpty &&
        selectedRoadIds.isEmpty) {
      if (selectedObstacleIds.length == 1) {
        final obstacle = grid.findObstacle(selectedObstacleIds.first);
        if (obstacle == null) return const SizedBox.shrink();
        return _buildSingleObstacleProperties(context, obstacle);
      }
      return _buildMultiObstacleProperties(context);
    }

    return _buildMixedSelectionProperties(context);
  }

  Widget _buildSingleSpotProperties(BuildContext context, ParkingSpot spot) {
    return Container(
      width: 200,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Spot Properties',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildTextField(context, 'ID', spot.id, (val) {},
                enabled: false, key: ValueKey('id_${spot.id}')),
            const SizedBox(height: 8),
            _buildNumberField(context, 'X', spot.x, (val) {
              spot.x = val;
              onStateChanged();
            }, key: ValueKey('x_${spot.id}')),
            const SizedBox(height: 8),
            _buildNumberField(context, 'Y', spot.y, (val) {
              spot.y = val;
              onStateChanged();
            }, key: ValueKey('y_${spot.id}')),
            const SizedBox(height: 8),
            _buildNumberField(context, 'Width', spot.width, (val) {
              spot.width = val;
              onStateChanged();
            }, key: ValueKey('w_${spot.id}')),
            const SizedBox(height: 8),
            _buildNumberField(context, 'Height', spot.height, (val) {
              spot.height = val;
              onStateChanged();
            }, key: ValueKey('h_${spot.id}')),
            const SizedBox(height: 8),
            Text('Type: ${spot.type.name}',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            DropdownButton<SpotType>(
              value: spot.type,
              isExpanded: true,
              dropdownColor: Theme.of(context).cardTheme.color,
              items: SpotType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.name),
                );
              }).toList(),
              onChanged: (newType) {
                if (newType != null) {
                  spot.type = newType;
                  onStateChanged();
                }
              },
            ),
            const SizedBox(height: 8),
            _buildTextField(
              context,
              'Label',
              spot.label ?? '',
              (val) {
                spot.label = val.isEmpty ? null : val;
                onStateChanged();
              },
              key: ValueKey('label_${spot.id}'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => onRotateSpot(spot.id),
                    icon: const Icon(Icons.rotate_right, size: 18),
                    label: const Text('Rotate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      minimumSize: const Size(0, 40),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: onDeleteSelected,
              icon: const Icon(Icons.delete, size: 18),
              label: const Text('Delete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiSpotProperties(BuildContext context) {
    return Container(
      width: 200,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${selectedSpotIds.length} Spots Selected',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'Bulk Edit',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButton<SpotType>(
            isExpanded: true,
            hint: const Text("Change Type"),
            dropdownColor: Theme.of(context).cardTheme.color,
            items: SpotType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type.name),
              );
            }).toList(),
            onChanged: (newType) {
              if (newType != null) {
                for (final id in selectedSpotIds) {
                  final spot = grid.findSpot(id);
                  if (spot != null) spot.type = newType;
                }
                onStateChanged();
              }
            },
          ),
          const SizedBox(height: 8),
          _LabelPrefixWidget(
            selectedSpotIds: selectedSpotIds,
            grid: grid,
            onStateChanged: onStateChanged,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRotateSelected,
            icon: const Icon(Icons.rotate_right, size: 18),
            label: const Text('Rotate All'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: onDeleteSelected,
            icon: const Icon(Icons.delete, size: 18),
            label: const Text('Delete Selected'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(BuildContext context, String label, String value,
      Function(String) onChanged,
      {bool enabled = true, Key? key}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12)),
        SizedBox(
          height: 30,
          child: _DebouncedTextField(
            key: key,
            initialValue: value,
            enabled: enabled,
            onValueChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildNumberField(BuildContext context, String label, double value,
      Function(double) onChanged,
      {Key? key}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12)),
        SizedBox(
          height: 30,
          child: _DebouncedNumberField(
            key: key,
            initialValue: value,
            onValueChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildSingleRoadProperties(BuildContext context, Road road) {
    return Container(
      width: 200,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Road Properties',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          _buildTextField(context, 'ID', road.id, (val) {},
              enabled: false, key: ValueKey('road_id_${road.id}')),
          const SizedBox(height: 8),
          _buildNumberField(context, 'X', road.x, (val) {
            road.x = val;
            onStateChanged();
          }, key: ValueKey('road_x_${road.id}')),
          const SizedBox(height: 8),
          _buildNumberField(context, 'Y', road.y, (val) {
            road.y = val;
            onStateChanged();
          }, key: ValueKey('road_y_${road.id}')),
          const SizedBox(height: 8),
          _buildNumberField(context, 'Width', road.width, (val) {
            road.width = val;
            onStateChanged();
          }, key: ValueKey('road_w_${road.id}')),
          const SizedBox(height: 8),
          _buildNumberField(context, 'Height', road.height, (val) {
            road.height = val;
            onStateChanged();
          }, key: ValueKey('road_h_${road.id}')),
          const SizedBox(height: 8),
          _buildTextField(
            context,
            'Label',
            road.label ?? '',
            (val) {
              road.label = val.isEmpty ? null : val;
              onStateChanged();
            },
            key: ValueKey('road_label_${road.id}'),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onDeleteRoads ?? onDeleteSelected,
            icon: const Icon(Icons.delete, size: 18),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiRoadProperties(BuildContext context) {
    return Container(
      width: 200,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${selectedRoadIds.length} Roads Selected',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          _RoadLabelPrefixWidget(
            selectedRoadIds: selectedRoadIds,
            grid: grid,
            onStateChanged: onStateChanged,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onDeleteRoads ?? onDeleteSelected,
            icon: const Icon(Icons.delete, size: 18),
            label: const Text('Delete Selected'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleObstacleProperties(
      BuildContext context, Obstacle obstacle) {
    return Container(
      width: 200,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Obstacle Properties',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          _buildTextField(context, 'ID', obstacle.id, (val) {},
              enabled: false, key: ValueKey('obs_id_${obstacle.id}')),
          const SizedBox(height: 8),
          _buildNumberField(context, 'X', obstacle.x, (val) {
            obstacle.x = val;
            onStateChanged();
          }, key: ValueKey('obs_x_${obstacle.id}')),
          const SizedBox(height: 8),
          _buildNumberField(context, 'Y', obstacle.y, (val) {
            obstacle.y = val;
            onStateChanged();
          }, key: ValueKey('obs_y_${obstacle.id}')),
          const SizedBox(height: 8),
          _buildNumberField(context, 'Width', obstacle.width, (val) {
            obstacle.width = val;
            onStateChanged();
          }, key: ValueKey('obs_w_${obstacle.id}')),
          const SizedBox(height: 8),
          _buildNumberField(context, 'Height', obstacle.height, (val) {
            obstacle.height = val;
            onStateChanged();
          }, key: ValueKey('obs_h_${obstacle.id}')),
          const SizedBox(height: 8),
          Text('Type: ${obstacle.type.name}',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          DropdownButton<ObstacleType>(
            value: obstacle.type,
            isExpanded: true,
            dropdownColor: Theme.of(context).cardTheme.color,
            items: ObstacleType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type.name),
              );
            }).toList(),
            onChanged: (newType) {
              if (newType != null) {
                obstacle.type = newType;
                onStateChanged();
              }
            },
          ),
          const SizedBox(height: 8),
          _buildTextField(
            context,
            'Label',
            obstacle.label ?? '',
            (val) {
              obstacle.label = val.isEmpty ? null : val;
              onStateChanged();
            },
            key: ValueKey('obs_label_${obstacle.id}'),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onDeleteObstacles ?? onDeleteSelected,
            icon: const Icon(Icons.delete, size: 18),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiObstacleProperties(BuildContext context) {
    return Container(
      width: 200,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${selectedObstacleIds.length} Obstacles Selected',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'Bulk Edit',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButton<ObstacleType>(
            isExpanded: true,
            hint: const Text("Change Type"),
            dropdownColor: Theme.of(context).cardTheme.color,
            items: ObstacleType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type.name),
              );
            }).toList(),
            onChanged: (newType) {
              if (newType != null) {
                for (final id in selectedObstacleIds) {
                  final obstacle = grid.findObstacle(id);
                  if (obstacle != null) obstacle.type = newType;
                }
                onStateChanged();
              }
            },
          ),
          const SizedBox(height: 8),
          _ObstacleLabelPrefixWidget(
            selectedObstacleIds: selectedObstacleIds,
            grid: grid,
            onStateChanged: onStateChanged,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onDeleteObstacles ?? onDeleteSelected,
            icon: const Icon(Icons.delete, size: 18),
            label: const Text('Delete Selected'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMixedSelectionProperties(BuildContext context) {
    final totalCount = selectedSpotIds.length +
        selectedRoadIds.length +
        selectedObstacleIds.length;
    return Container(
      width: 200,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$totalCount Items Selected',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (selectedSpotIds.isNotEmpty)
            Text('• ${selectedSpotIds.length} Spots',
                style: Theme.of(context).textTheme.bodySmall),
          if (selectedRoadIds.isNotEmpty)
            Text('• ${selectedRoadIds.length} Roads',
                style: Theme.of(context).textTheme.bodySmall),
          if (selectedObstacleIds.isNotEmpty)
            Text('• ${selectedObstacleIds.length} Obstacles',
                style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onDeleteSelected,
            icon: const Icon(Icons.delete, size: 18),
            label: const Text('Delete All'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelPrefixWidget extends StatefulWidget {
  final Set<String> selectedSpotIds;
  final ParkingGrid grid;
  final VoidCallback onStateChanged;

  const _LabelPrefixWidget({
    required this.selectedSpotIds,
    required this.grid,
    required this.onStateChanged,
  });

  @override
  State<_LabelPrefixWidget> createState() => _LabelPrefixWidgetState();
}

class _LabelPrefixWidgetState extends State<_LabelPrefixWidget> {
  final TextEditingController _prefixController =
      TextEditingController(text: 'A');
  int _startNumber = 1;

  @override
  void dispose() {
    _prefixController.dispose();
    super.dispose();
  }

  void _applyLabels() {
    final sortedIds = widget.selectedSpotIds.toList()..sort();
    int counter = _startNumber;
    for (final id in sortedIds) {
      final spot = widget.grid.findSpot(id);
      if (spot != null) {
        spot.label = '${_prefixController.text}$counter';
        counter++;
      }
    }
    widget.onStateChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bulk Label',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 30,
                child: TextFormField(
                  controller: _prefixController,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Prefix',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: SizedBox(
                height: 30,
                child: TextFormField(
                  initialValue: _startNumber.toString(),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: '#',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    final num = int.tryParse(val);
                    if (num != null) {
                      _startNumber = num;
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ElevatedButton(
          onPressed: _applyLabels,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 32),
          ),
          child: Text(
              'Apply (${_prefixController.text}$_startNumber, ${_prefixController.text}${_startNumber + 1}...)'),
        ),
      ],
    );
  }
}

class _RoadLabelPrefixWidget extends StatefulWidget {
  final Set<String> selectedRoadIds;
  final ParkingGrid grid;
  final VoidCallback onStateChanged;

  const _RoadLabelPrefixWidget({
    required this.selectedRoadIds,
    required this.grid,
    required this.onStateChanged,
  });

  @override
  State<_RoadLabelPrefixWidget> createState() => _RoadLabelPrefixWidgetState();
}

class _RoadLabelPrefixWidgetState extends State<_RoadLabelPrefixWidget> {
  final TextEditingController _prefixController =
      TextEditingController(text: 'R');
  int _startNumber = 1;

  @override
  void dispose() {
    _prefixController.dispose();
    super.dispose();
  }

  void _applyLabels() {
    final sortedIds = widget.selectedRoadIds.toList()..sort();
    int counter = _startNumber;
    for (final id in sortedIds) {
      final road = widget.grid.findRoad(id);
      if (road != null) {
        road.label = '${_prefixController.text}$counter';
        counter++;
      }
    }
    widget.onStateChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bulk Label',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 30,
                child: TextFormField(
                  controller: _prefixController,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Prefix',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: SizedBox(
                height: 30,
                child: TextFormField(
                  initialValue: _startNumber.toString(),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: '#',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    final num = int.tryParse(val);
                    if (num != null) {
                      _startNumber = num;
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ElevatedButton(
          onPressed: _applyLabels,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 32),
          ),
          child: Text(
              'Apply (${_prefixController.text}$_startNumber, ${_prefixController.text}${_startNumber + 1}...)'),
        ),
      ],
    );
  }
}

class _ObstacleLabelPrefixWidget extends StatefulWidget {
  final Set<String> selectedObstacleIds;
  final ParkingGrid grid;
  final VoidCallback onStateChanged;

  const _ObstacleLabelPrefixWidget({
    required this.selectedObstacleIds,
    required this.grid,
    required this.onStateChanged,
  });

  @override
  State<_ObstacleLabelPrefixWidget> createState() =>
      _ObstacleLabelPrefixWidgetState();
}

class _ObstacleLabelPrefixWidgetState
    extends State<_ObstacleLabelPrefixWidget> {
  final TextEditingController _prefixController =
      TextEditingController(text: 'P');
  int _startNumber = 1;

  @override
  void dispose() {
    _prefixController.dispose();
    super.dispose();
  }

  void _applyLabels() {
    final sortedIds = widget.selectedObstacleIds.toList()..sort();
    int counter = _startNumber;
    for (final id in sortedIds) {
      final obstacle = widget.grid.findObstacle(id);
      if (obstacle != null) {
        obstacle.label = '${_prefixController.text}$counter';
        counter++;
      }
    }
    widget.onStateChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bulk Label',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 30,
                child: TextFormField(
                  controller: _prefixController,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Prefix',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: SizedBox(
                height: 30,
                child: TextFormField(
                  initialValue: _startNumber.toString(),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: '#',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    final num = int.tryParse(val);
                    if (num != null) {
                      _startNumber = num;
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ElevatedButton(
          onPressed: _applyLabels,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 32),
          ),
          child: Text(
              'Apply (${_prefixController.text}$_startNumber, ${_prefixController.text}${_startNumber + 1}...)'),
        ),
      ],
    );
  }
}

class _DebouncedTextField extends StatefulWidget {
  final String initialValue;
  final bool enabled;
  final Function(String) onValueChanged;

  const _DebouncedTextField({
    super.key,
    required this.initialValue,
    this.enabled = true,
    required this.onValueChanged,
  });

  @override
  State<_DebouncedTextField> createState() => _DebouncedTextFieldState();
}

class _DebouncedTextFieldState extends State<_DebouncedTextField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  String _lastValue = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _lastValue = widget.initialValue;
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _controller.text != _lastValue) {
      _lastValue = _controller.text;
      widget.onValueChanged(_controller.text);
    }
  }

  @override
  void didUpdateWidget(_DebouncedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue && !_focusNode.hasFocus) {
      _controller.text = widget.initialValue;
      _lastValue = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      style: const TextStyle(fontSize: 12),
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(),
      ),
    );
  }
}

class _DebouncedNumberField extends StatefulWidget {
  final double initialValue;
  final Function(double) onValueChanged;

  const _DebouncedNumberField({
    super.key,
    required this.initialValue,
    required this.onValueChanged,
  });

  @override
  State<_DebouncedNumberField> createState() => _DebouncedNumberFieldState();
}

class _DebouncedNumberFieldState extends State<_DebouncedNumberField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  double _lastValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue.toString());
    _lastValue = widget.initialValue;
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      final parsed = double.tryParse(_controller.text);
      if (parsed != null && parsed != _lastValue) {
        _lastValue = parsed;
        widget.onValueChanged(parsed);
      }
    }
  }

  @override
  void didUpdateWidget(_DebouncedNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue && !_focusNode.hasFocus) {
      _controller.text = widget.initialValue.toString();
      _lastValue = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 12),
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(),
      ),
    );
  }
}
