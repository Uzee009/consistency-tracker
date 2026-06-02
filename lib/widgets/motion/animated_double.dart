import 'package:flutter/material.dart';
import '../../theme/motion.dart';
import '../../utils/motion_accessibility.dart';

/// Animated double value. See CURRENT_MODULE.md Step 17 for scope.
class AnimatedDouble extends StatefulWidget {
  final double value;
  final String Function(double) formatter;
  final TextStyle? style;
  final Duration? duration;
  final Curve? curve;

  const AnimatedDouble({
    super.key,
    required this.value,
    required this.formatter,
    this.style,
    this.duration,
    this.curve,
  });

  @override
  State<AnimatedDouble> createState() => _AnimatedDoubleState();
}

class _AnimatedDoubleState extends State<AnimatedDouble> {
  @override
  Widget build(BuildContext context) {
    final accessibility = MotionAccessibility.of(context);
    if (accessibility.reduce) {
      return Text(widget.formatter(widget.value), style: widget.style);
    }

    final effectiveDuration = accessibility.apply(widget.duration ?? Motion.medium);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: widget.value),
      duration: effectiveDuration,
      curve: widget.curve ?? Motion.standardEase,
      builder: (context, value, child) {
        return Text(widget.formatter(value), style: widget.style);
      },
    );
  }
}
