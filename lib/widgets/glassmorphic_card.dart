import 'dart:ui';
import 'package:flutter/material.dart';

/// A premium glassmorphic card with blur effect and gradient border
class GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blur;
  final Color? borderColor;
  final double borderWidth;
  final List<Color>? gradientColors;
  final VoidCallback? onTap;

  const GlassmorphicCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 24,
    this.blur = 0, // Disabled by default for performance - set > 0 to enable
    this.borderColor,
    this.borderWidth = 1.5,
    this.gradientColors,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultGradient = isDark
        ? [
            const Color(0xFF00BFA5).withValues(alpha: 0.3),
            const Color(0xFF00ACC1).withValues(alpha: 0.2),
          ]
        : [
            const Color(0xFF00BFA5).withValues(alpha: 0.15),
            const Color(0xFF00ACC1).withValues(alpha: 0.1),
          ];

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors ?? defaultGradient,
            ),
            border: Border.all(
              color: borderColor ??
                  (isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.6)),
              width: borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00BFA5)
                    .withValues(alpha: isDark ? 0.15 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            // Only apply BackdropFilter if blur > 0 (expensive operation)
            child: blur > 0
                ? BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                    child: _buildInnerContainer(isDark),
                  )
                : _buildInnerContainer(isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildInnerContainer(bool isDark) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: child,
    );
  }
}

/// Interactive glassmorphic card with hover and tap animations
class InteractiveGlassmorphicCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;
  final Color? accentColor;

  const InteractiveGlassmorphicCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 24,
    this.onTap,
    this.accentColor,
  });

  @override
  State<InteractiveGlassmorphicCard> createState() =>
      _InteractiveGlassmorphicCardState();
}

class _InteractiveGlassmorphicCardState
    extends State<InteractiveGlassmorphicCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHover(bool hover) {
    // Avoid setState when hover state hasn't changed
    if (_isHovered == hover) return;
    _isHovered = hover;
    if (hover) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.accentColor ?? const Color(0xFF00BFA5);

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => _onHover(true),
        onExit: (_) => _onHover(false),
        child: GestureDetector(
          onTap: widget.onTap,
          onTapDown: (_) => _controller.forward(),
          onTapUp: (_) => _controller.reverse(),
          onTapCancel: () => _controller.reverse(),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent.withValues(
                            alpha: 0.15 + (_glowAnimation.value * 0.1)),
                        accent.withValues(
                            alpha: 0.08 + (_glowAnimation.value * 0.07)),
                      ],
                    ),
                    border: Border.all(
                      color: _isHovered
                          ? accent.withValues(alpha: 0.5)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.6)),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(
                            alpha: 0.1 + (_glowAnimation.value * 0.15)),
                        blurRadius: 20 + (_glowAnimation.value * 10),
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  // Removed expensive BackdropFilter - use child parameter for caching
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    child: Container(
                      padding: widget.padding,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.85),
                        borderRadius:
                            BorderRadius.circular(widget.borderRadius),
                      ),
                      child: child, // Cached child widget
                    ),
                  ),
                ),
              );
            },
            child: widget.child, // Child is built once and cached
          ),
        ),
      ),
    );
  }
}
