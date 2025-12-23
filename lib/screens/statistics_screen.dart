import 'dart:async';
import 'package:flutter/material.dart';
import '../services/dynamodb_service.dart';
import '../widgets/animated_gradient_background.dart';
import '../widgets/stat_card.dart';
import 'map.dart';

enum SpotFilter { all, available, occupied }

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final DynamoDBService _dynamoDBService = DynamoDBService();
  List<ParkingSpotData> _parkingSpots = [];
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _refreshTimer;
  SpotFilter _currentFilter = SpotFilter.all;
  final TextEditingController _searchController = TextEditingController();

  // Computed heuristics from parking data
  Map<String, int> get _hourlyOccupancy {
    final Map<String, int> hourlyData = {};
    for (int i = 0; i < 24; i++) {
      hourlyData['${i.toString().padLeft(2, '0')}:00'] = 0;
    }
    for (final spot in _parkingSpots.where((s) => s.isOccupied)) {
      try {
        DateTime dateTime = DateTime.parse(spot.lastUpdated);
        if (!spot.lastUpdated.endsWith('Z') &&
            !spot.lastUpdated.contains('+') &&
            !spot.lastUpdated.contains('-', 10)) {
          dateTime = DateTime.parse('${spot.lastUpdated}Z');
        }
        final hour = dateTime.toUtc().add(const Duration(hours: 7)).hour;
        final key = '${hour.toString().padLeft(2, '0')}:00';
        hourlyData[key] = (hourlyData[key] ?? 0) + 1;
      } catch (_) {}
    }
    return hourlyData;
  }

  String get _peakHour {
    if (_parkingSpots.isEmpty) return 'N/A';
    final hourlyData = _hourlyOccupancy;
    if (hourlyData.isEmpty) return 'N/A';
    final maxEntry =
        hourlyData.entries.reduce((a, b) => a.value > b.value ? a : b);
    return maxEntry.value > 0 ? maxEntry.key : 'N/A';
  }

  String get _quietHour {
    if (_parkingSpots.isEmpty) return 'N/A';
    final hourlyData = _hourlyOccupancy;
    if (hourlyData.isEmpty) return 'N/A';
    final minEntry =
        hourlyData.entries.reduce((a, b) => a.value < b.value ? a : b);
    return minEntry.key;
  }

  Duration get _averageOccupancyDuration {
    final occupiedSpots = _parkingSpots.where((s) => s.isOccupied).toList();
    if (occupiedSpots.isEmpty) return Duration.zero;

    final now = DateTime.now().toUtc();
    var totalDuration = Duration.zero;
    int validCount = 0;

    for (final spot in occupiedSpots) {
      try {
        DateTime dateTime = DateTime.parse(spot.lastUpdated);
        if (!spot.lastUpdated.endsWith('Z') &&
            !spot.lastUpdated.contains('+') &&
            !spot.lastUpdated.contains('-', 10)) {
          dateTime = DateTime.parse('${spot.lastUpdated}Z');
        }
        totalDuration += now.difference(dateTime);
        validCount++;
      } catch (_) {}
    }

    if (validCount == 0) return Duration.zero;
    return Duration(minutes: totalDuration.inMinutes ~/ validCount);
  }

  List<ParkingSpotData> get _recentActivity {
    final sortedSpots = List<ParkingSpotData>.from(_parkingSpots);
    sortedSpots.sort((a, b) {
      try {
        return DateTime.parse(b.lastUpdated)
            .compareTo(DateTime.parse(a.lastUpdated));
      } catch (_) {
        return 0;
      }
    });
    return sortedSpots.take(5).toList();
  }

  double get _turnoverRate {
    // Estimated turnover: number of status changes per hour
    // This is a simplified heuristic based on recent updates
    if (_parkingSpots.isEmpty) return 0.0;

    final now = DateTime.now().toUtc();
    int changesInLastHour = 0;

    for (final spot in _parkingSpots) {
      try {
        DateTime dateTime = DateTime.parse(spot.lastUpdated);
        if (!spot.lastUpdated.endsWith('Z') &&
            !spot.lastUpdated.contains('+') &&
            !spot.lastUpdated.contains('-', 10)) {
          dateTime = DateTime.parse('${spot.lastUpdated}Z');
        }
        if (now.difference(dateTime).inMinutes <= 60) {
          changesInLastHour++;
        }
      } catch (_) {}
    }

    return changesInLastHour.toDouble();
  }

  String get _efficiencyRating {
    final occupancyRate = _parkingSpots.isNotEmpty
        ? _parkingSpots.where((s) => s.isOccupied).length / _parkingSpots.length
        : 0.0;

    if (occupancyRate < 0.3) return 'Low Usage';
    if (occupancyRate < 0.6) return 'Moderate';
    if (occupancyRate < 0.85) return 'Optimal';
    return 'High Demand';
  }

  Color get _efficiencyColor {
    final rating = _efficiencyRating;
    switch (rating) {
      case 'Low Usage':
        return const Color(0xFF3B82F6); // Blue
      case 'Moderate':
        return const Color(0xFF10B981); // Green
      case 'Optimal':
        return const Color(0xFFF59E0B); // Amber
      case 'High Demand':
        return const Color(0xFFF43F5E); // Red
      default:
        return const Color(0xFF6B7280); // Gray
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchParkingData();
    _refreshTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      _fetchParkingData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchParkingData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final spots = await _dynamoDBService.fetchParkingSpots();
      if (mounted) {
        setState(() {
          _parkingSpots = spots;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<ParkingSpotData> get _filteredSpots {
    List<ParkingSpotData> spots;
    switch (_currentFilter) {
      case SpotFilter.available:
        spots = _parkingSpots.where((s) => !s.isOccupied).toList();
      case SpotFilter.occupied:
        spots = _parkingSpots.where((s) => s.isOccupied).toList();
      case SpotFilter.all:
        spots = _parkingSpots;
    }

    // Apply search filter
    final searchQuery = _searchController.text;
    if (searchQuery.isNotEmpty) {
      spots = spots
          .where(
              (s) => s.spotId.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();
    }

    return spots;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Parking Statistics"),
        backgroundColor: Colors.transparent,
        actions: [
          // Navigate to Map button
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.map_rounded,
                color: Color(0xFF3B82F6),
                size: 20,
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MapScreen()),
              );
            },
            tooltip: 'View Map',
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.refresh,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            onPressed: _fetchParkingData,
            tooltip: 'Refresh data',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: GradientBackground(
        child: SafeArea(
          child: _buildBody(isDark),
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Loading parking data...',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _buildGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Failed to load data',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _fetchParkingData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_parkingSpots.isEmpty) {
      return Center(
        child: _buildGlassCard(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.local_parking,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'No parking data available',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _fetchParkingData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Calculate statistics
    final occupiedCount = _parkingSpots.where((s) => s.isOccupied).length;
    final availableCount = _parkingSpots.length - occupiedCount;
    final occupancyRate = (_parkingSpots.isNotEmpty)
        ? (occupiedCount / _parkingSpots.length * 100).round()
        : 0;

    return RefreshIndicator(
      onRefresh: _fetchParkingData,
      color: Theme.of(context).colorScheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary cards - uniform charcoal background with colored icons/text
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: AnimatedStatCard(
                      title: 'Total Spots',
                      value: _parkingSpots.length,
                      icon: Icons.local_parking,
                      color: const Color(0xFF3B82F6), // Electric blue
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnimatedStatCard(
                      title: 'Occupied',
                      value: occupiedCount,
                      icon: Icons.directions_car,
                      color: const Color(0xFFF43F5E), // Rose red
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnimatedStatCard(
                      title: 'Available',
                      value: availableCount,
                      icon: Icons.check_circle,
                      color: const Color(0xFF10B981), // Emerald green
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Quick Action - Navigate to nearest spot
            if (availableCount > 0)
              _buildGlassCard(
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const MapScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF10B981).withValues(alpha: 0.2),
                                const Color(0xFF10B981).withValues(alpha: 0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.navigation_rounded,
                            color: Color(0xFF10B981),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Navigate to nearest spot',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0D1B2A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$availableCount spots available now',
                                style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Color(0xFF10B981),
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Occupancy rate bar
            _buildGlassCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Occupancy Rate',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color:
                                isDark ? Colors.white : const Color(0xFF0D1B2A),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getOccupancyColor(occupancyRate)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$occupancyRate%',
                            style: TextStyle(
                              color: _getOccupancyColor(occupancyRate),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: occupancyRate / 100),
                        duration: const Duration(milliseconds: 1500),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Stack(
                            children: [
                              Container(
                                height: 12,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : Colors.grey.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: value,
                                child: Container(
                                  height: 12,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        _getOccupancyColor(occupancyRate),
                                        _getOccupancyColor(occupancyRate)
                                            .withValues(alpha: 0.7),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _getOccupancyColor(occupancyRate)
                                            .withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Insights Row - Peak Hours & Efficiency
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildInsightCard(
                      title: 'Peak Hour',
                      value: _peakHour,
                      subtitle: 'Busiest time',
                      icon: Icons.trending_up_rounded,
                      color: const Color(0xFFF43F5E),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInsightCard(
                      title: 'Quiet Hour',
                      value: _quietHour,
                      subtitle: 'Best time to park',
                      icon: Icons.trending_down_rounded,
                      color: const Color(0xFF10B981),
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Efficiency & Duration Row
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildInsightCard(
                      title: 'Efficiency',
                      value: _efficiencyRating,
                      subtitle: 'Utilization status',
                      icon: Icons.speed_rounded,
                      color: _efficiencyColor,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInsightCard(
                      title: 'Avg Duration',
                      value: _formatDuration(_averageOccupancyDuration),
                      subtitle: 'Per occupied spot',
                      icon: Icons.timer_rounded,
                      color: const Color(0xFF8B5CF6),
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Turnover Rate Card
            _buildGlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFF59E0B).withValues(alpha: 0.2),
                            const Color(0xFFF59E0B).withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.swap_horiz_rounded,
                        color: Color(0xFFF59E0B),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Turnover Rate',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_turnoverRate.toInt()} changes/hour',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0D1B2A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _turnoverRate > 5 ? 'Active' : 'Stable',
                        style: const TextStyle(
                          color: Color(0xFFF59E0B),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Recent Activity Section
            if (_recentActivity.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0D1B2A),
                      ),
                    ),
                    StatPill(
                      label: 'updates',
                      value: '${_recentActivity.length}',
                      color: const Color(0xFF8B5CF6),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildRecentActivityTimeline(isDark),
              const SizedBox(height: 16),
            ],

            // Search bar
            _buildGlassCard(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: isDark ? Colors.white60 : Colors.black54,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {});
                        },
                        style: TextStyle(
                          color:
                              isDark ? Colors.white : const Color(0xFF0D1B2A),
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search spot by ID...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    Visibility(
                      visible: _searchController.text.isNotEmpty,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _searchController.clear();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: isDark ? Colors.white60 : Colors.black54,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    label: 'Show All',
                    icon: Icons.grid_view_rounded,
                    isSelected: _currentFilter == SpotFilter.all,
                    onTap: () =>
                        setState(() => _currentFilter = SpotFilter.all),
                    color: const Color(0xFF3B82F6),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: 'Available Only',
                    icon: Icons.check_circle_outline,
                    isSelected: _currentFilter == SpotFilter.available,
                    onTap: () =>
                        setState(() => _currentFilter = SpotFilter.available),
                    color: const Color(0xFF10B981),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: 'Occupied Only',
                    icon: Icons.directions_car_outlined,
                    isSelected: _currentFilter == SpotFilter.occupied,
                    onTap: () =>
                        setState(() => _currentFilter = SpotFilter.occupied),
                    color: const Color(0xFFF43F5E),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Parking spots list header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Parking Spots',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0D1B2A),
                    ),
                  ),
                  StatPill(
                    label: 'spots',
                    value: '${_filteredSpots.length}',
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Spot cards
            ...List.generate(_filteredSpots.length, (index) {
              final spot = _filteredSpots[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildSpotCard(spot, isDark),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.2)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.3)),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? color
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? color
                    : (isDark ? Colors.white70 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getOccupancyColor(int rate) {
    if (rate < 50) return const Color(0xFF10B981);
    if (rate < 80) return const Color(0xFFF59E0B);
    return const Color(0xFFF43F5E);
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes == 0) return '0m';
    if (duration.inHours == 0) return '${duration.inMinutes}m';
    if (duration.inHours < 24) {
      final mins = duration.inMinutes % 60;
      return '${duration.inHours}h ${mins}m';
    }
    return '${duration.inDays}d ${duration.inHours % 24}h';
  }

  Widget _buildInsightCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return _buildGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.2),
                        color.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityTimeline(bool isDark) {
    return _buildGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: _recentActivity.asMap().entries.map((entry) {
            final index = entry.key;
            final spot = entry.value;
            final isLast = index == _recentActivity.length - 1;
            final statusColor = spot.isOccupied
                ? const Color(0xFFF43F5E)
                : const Color(0xFF10B981);

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline indicator
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withValues(alpha: 0.4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              statusColor.withValues(alpha: 0.4),
                              statusColor.withValues(alpha: 0.1),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                // Activity content
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Spot ${spot.spotId}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0D1B2A),
                                ),
                              ),
                              Text(
                                spot.isOccupied ? 'Occupied' : 'Vacated',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _formatTimeAgo(spot.lastUpdated),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  String _formatTimeAgo(String timestamp) {
    try {
      DateTime dateTime = DateTime.parse(timestamp);
      if (!timestamp.endsWith('Z') &&
          !timestamp.contains('+') &&
          !timestamp.contains('-', 10)) {
        dateTime = DateTime.parse('${timestamp}Z');
      }
      final now = DateTime.now().toUtc();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      return '${difference.inDays}d ago';
    } catch (_) {
      return timestamp;
    }
  }

  Widget _buildGlassCard({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Removed BackdropFilter for performance - especially important in lists
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: child,
      ),
    );
  }

  Widget _buildSpotCard(ParkingSpotData spot, bool isDark) {
    final statusColor =
        spot.isOccupied ? const Color(0xFFF43F5E) : const Color(0xFF10B981);

    return _buildGlassCard(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                statusColor.withValues(alpha: 0.25),
                statusColor.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            spot.isOccupied ? Icons.directions_car : Icons.check,
            color: statusColor,
            size: 24,
          ),
        ),
        title: Text(
          'Spot ${spot.spotId}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0D1B2A),
          ),
        ),
        // Removed redundant "Status: Available" text - badge on right is sufficient
        subtitle: Text(
          _formatTimestampWithLabel(spot.lastUpdated, spot.isOccupied),
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 12,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                statusColor.withValues(alpha: 0.2),
                statusColor.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            spot.isOccupied ? 'Occupied' : 'Available',
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimestampWithLabel(String timestamp, bool isOccupied) {
    try {
      DateTime dateTime = DateTime.parse(timestamp);
      if (!timestamp.endsWith('Z') &&
          !timestamp.contains('+') &&
          !timestamp.contains('-', 10)) {
        dateTime = DateTime.parse('${timestamp}Z');
      }
      final utc7Time = dateTime.toUtc().add(const Duration(hours: 7));
      final timeStr =
          '${utc7Time.hour.toString().padLeft(2, '0')}:${utc7Time.minute.toString().padLeft(2, '0')}';

      // Add meaningful label based on status
      if (isOccupied) {
        return 'Occupied since: $timeStr';
      } else {
        return 'Last vacated: $timeStr';
      }
    } catch (e) {
      return timestamp;
    }
  }
}
