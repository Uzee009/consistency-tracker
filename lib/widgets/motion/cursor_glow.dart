import 'package:flutter/material.dart';
import '../../theme/motion.dart';
import '../../utils/motion_accessibility.dart';

class CursorGlow extends StatefulWidget {
  final Widget child;
  final double radius;
  final Color? color;
  final double maxOpacity;

  const CursorGlow({
    super.key,
    required this.child,
    this.radius = 100,
    this.color,
    this.maxOpacity = 0.035,
  });

  @override
  State<CursorGlow> createState() => _CursorGlowState();
}

class _CursorGlowState extends State<CursorGlow> {
  Offset? _localPosition;
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final motion = MotionAccessibility.of(context);
    if (motion.reduce) return widget.child;

    return MouseRegion(
      onHover: (event) {
        setState(() {
          _localPosition = event.localPosition;
          _isHovering = true;
        });
      },
      onExit: (_) {
        setState(() {
          _isHovering = false;
        });
      },
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _isHovering ? 1.0 : 0.0,
                duration: motion.apply(Motion.fast),
                curve: Motion.standardEase,
                child: CustomPaint(
                  painter: _GlowPainter(
                    position: _localPosition,
                    radius: widget.radius,
                    color: widget.color ?? Theme.of(context).colorScheme.primary,
                    maxOpacity: widget.maxOpacity,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  final Offset? position;
  final double radius;
  final Color color;
  final double maxOpacity;

  _GlowPainter({
    required this.position,
    required this.radius,
    required this.color,
    required this.maxOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (position == null) return;

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: maxOpacity),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: position!, radius: radius));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) {
    return oldDelegate.position != position ||
        oldDelegate.radius != radius ||
        oldDelegate.color != color ||
        oldDelegate.maxOpacity != maxOpacity;
  }
}
