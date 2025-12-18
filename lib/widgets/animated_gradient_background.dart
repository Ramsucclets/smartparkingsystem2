import 'package:flutter/material.dart';

/// Animated gradient background with optional floating orbs
class AnimatedGradientBackground extends StatefulWidget {
  final Widget child;
  final List<Color>? colors;
  final bool showOrbs;
  final bool animate;

  const AnimatedGradientBackground({
    super.key,
    required this.child,
    this.colors,
    this.showOrbs = false, // Disabled by default - too distracting
    this.animate = false, // Static by default for less distraction
  });

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60), // Very slow for subtlety
    );
    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultColors = isDark
        ? [
            const Color(0xFF0D1B2A), // Deep dark blue
            const Color(0xFF1B3A4B), // Dark teal
            const Color(0xFF0D2818), // Dark green
          ]
        : [
            const Color(0xFFE0F7FA), // Light cyan
            const Color(0xFFB2DFDB), // Light teal
            const Color(0xFFE8F5E9), // Light green
          ];

    // Static gradient - no animation for less distraction
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.colors ?? defaultColors,
            ),
          ),
        ),
        // Content
        widget.child,
      ],
    );
  }
}

/// Simple gradient background without animation (for performance)
class GradientBackground extends StatelessWidget {
  final Widget child;
  final List<Color>? colors;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;

  const GradientBackground({
    super.key,
    required this.child,
    this.colors,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultColors = isDark
        ? [
            const Color(0xFF0D1B2A),
            const Color(0xFF1B3A4B),
          ]
        : [
            const Color(0xFFE0F7FA),
            const Color(0xFFB2DFDB),
          ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: begin,
          end: end,
          colors: colors ?? defaultColors,
        ),
      ),
      child: child,
    );
  }
}
