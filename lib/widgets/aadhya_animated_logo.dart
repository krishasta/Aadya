import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Animated Aadhya Logo where the outer circular swirl rotates smoothly
/// in slow-motion, while the center wording "Aadhya" remains perfectly stationary.
class AadhyaAnimatedLogo extends StatefulWidget {
  final double size;
  final Duration duration;
  final bool clockwise;
  final bool showGlow;
  final double glowOpacity;

  const AadhyaAnimatedLogo({
    super.key,
    this.size = 80,
    this.duration = const Duration(seconds: 14),
    this.clockwise = true,
    this.showGlow = false,
    this.glowOpacity = 0.35,
  });

  @override
  State<AadhyaAnimatedLogo> createState() => _AadhyaAnimatedLogoState();
}

class _AadhyaAnimatedLogoState extends State<AadhyaAnimatedLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant AadhyaAnimatedLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _rotationController.duration = widget.duration;
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final glowColor = isDark ? AppTheme.darkPrimary : AppTheme.primaryBlue;

    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Optional ambient glow behind the rotating circle
            if (widget.showGlow)
              Container(
                width: widget.size * 0.9,
                height: widget.size * 0.9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withValues(alpha: widget.glowOpacity),
                      blurRadius: widget.size * 0.35,
                      spreadRadius: widget.size * 0.05,
                    ),
                  ],
                ),
              ),

            // 1. ROTATING CIRCLE (Rotates in slow motion)
            AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                final double angle = widget.clockwise
                    ? _rotationController.value * 2 * 3.141592653589793
                    : -_rotationController.value * 2 * 3.141592653589793;
                return Transform.rotate(
                  angle: angle,
                  child: child,
                );
              },
              child: Image.asset(
                'assets/images/logo_circle.png',
                width: widget.size,
                height: widget.size,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            ),

            // 2. STATIONARY WORDING ("Aadhya" in the center - DOES NOT ROTATE)
            Image.asset(
              'assets/images/logo_text.png',
              width: widget.size,
              height: widget.size,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen ambient background watermark featuring the slow-motion rotating
/// Aadhya logo behind page content. Non-interactive (IgnorePointer).
class AadhyaAnimatedBackground extends StatelessWidget {
  final Widget? child;
  final double? size;
  final Alignment alignment;

  const AadhyaAnimatedBackground({
    super.key,
    this.child,
    this.size,
    this.alignment = const Alignment(0, -0.15),
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final logoSize = size ?? (screenSize.width * 0.72).clamp(240.0, 360.0);
    final isDark = AppTheme.isDark(context);

    // Subtle, elegant watermark opacity
    final double opacity = isDark ? 0.09 : 0.06;

    return Stack(
      children: [
        // Background animated watermark (IgnorePointer ensures touches pass through)
        Positioned.fill(
          child: IgnorePointer(
            ignoring: true,
            child: Align(
              alignment: alignment,
              child: Opacity(
                opacity: opacity,
                child: AadhyaAnimatedLogo(
                  size: logoSize,
                  duration: const Duration(seconds: 24), // Ultra-gentle slow-motion
                  clockwise: true,
                  showGlow: isDark,
                  glowOpacity: 0.25,
                ),
              ),
            ),
          ),
        ),

        // Foreground content
        ?child,
      ],
    );
  }
}
