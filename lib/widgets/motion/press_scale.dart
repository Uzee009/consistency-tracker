import 'package:flutter/material.dart';
import '../../theme/motion.dart';
import '../../utils/motion_accessibility.dart';

/// Scale on press. See CURRENT_MODULE.md Step 17 for scope.
class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final Duration? duration;

  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.96,
    this.duration,
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final accessibility = MotionAccessibility.of(context);
    if (accessibility.reduce) {
      return GestureDetector(
        onTap: widget.onTap,
        child: widget.child,
      );
    }

    final effectiveDuration = accessibility.apply(widget.duration ?? Motion.fast);

    return GestureDetector(
      behavior: HitTestBehavior.translucent, // Passthrough for underlying buttons
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? widget.pressedScale : 1.0,
        duration: effectiveDuration,
        curve: Motion.standardEase,
        child: widget.child,
      ),
    );
  }
}
