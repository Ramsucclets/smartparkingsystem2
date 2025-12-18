import 'dart:async';
import 'package:flutter/material.dart';
import '../services/dynamodb_service.dart';
import '../widgets/animated_gradient_background.dart';
import '../widgets/fade_slide_transition.dart';
import '../widgets/glassmorphic_card.dart';
import 'map.dart';
import 'setting_screen.dart';
import 'statistics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.username, super.key, required this.password});

  final String username;
  final String password;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DynamoDBService _dynamoDBService = DynamoDBService();
  List<ParkingSpotData> _parkingSpots = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchParkingData();
    // Auto-refresh every 3 minutes
    _refreshTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      _fetchParkingData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchParkingData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
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
          _isLoading = false;
        });
      }
    }
  }

  int get _occupiedCount => _parkingSpots.where((s) => s.isOccupied).length;
  int get _availableCount => _parkingSpots.length - _occupiedCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: AnimatedGradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with logo and greeting
                FadeSlideTransition(
                  index: 0,
                  child: GlassmorphicCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Logo with glow
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00BFA5)
                                    .withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/logo.png',
                              height: 80,
                              width: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back,',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.username,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0D1B2A),
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // User avatar placeholder
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00BFA5), Color(0xFF00ACC1)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Quick stats row
                FadeSlideTransition(
                  index: 1,
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildQuickStat(
                            context,
                            icon: Icons.local_parking,
                            value: _isLoading ? '...' : '$_availableCount',
                            label: 'Available',
                            color: const Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildQuickStat(
                            context,
                            icon: Icons.directions_car,
                            value: _isLoading ? '...' : '$_occupiedCount',
                            label: 'Occupied',
                            color: const Color(0xFFF43F5E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Menu section title
                FadeSlideTransition(
                  index: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 12),
                    child: Text(
                      'Quick Actions',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                    ),
                  ),
                ),

                // Menu cards
                FadeSlideTransition(
                  index: 3,
                  child: InteractiveGlassmorphicCard(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MapScreen(),
                        ),
                      );
                    },
                    accentColor: const Color(0xFF00BFA5),
                    child: _buildMenuContent(
                      context,
                      icon: Icons.map_rounded,
                      title: 'Find Parking',
                      subtitle: 'Locate nearby available spots',
                      color: const Color(0xFF3B82F6),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FadeSlideTransition(
                  index: 4,
                  child: InteractiveGlassmorphicCard(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StatisticsScreen(),
                        ),
                      );
                    },
                    accentColor: const Color(0xFF00ACC1),
                    child: _buildMenuContent(
                      context,
                      icon: Icons.bar_chart_rounded,
                      title: 'Statistics',
                      subtitle: 'View parking usage analytics',
                      color: const Color(0xFF8B5CF6),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FadeSlideTransition(
                  index: 5,
                  child: InteractiveGlassmorphicCard(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SettingScreen(),
                        ),
                      );
                    },
                    accentColor: const Color(0xFF26A69A),
                    child: _buildMenuContent(
                      context,
                      icon: Icons.settings_rounded,
                      title: 'Settings',
                      subtitle: 'Manage your preferences',
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Footer
                FadeSlideTransition(
                  index: 6,
                  child: Center(
                    child: Text(
                      '© Smarpar 2025',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.4)
                                : Colors.black.withValues(alpha: 0.4),
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStat(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuContent(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.25),
                color.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0D1B2A),
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.arrow_forward_ios_rounded,
            color: color,
            size: 16,
          ),
        ),
      ],
    );
  }
}
