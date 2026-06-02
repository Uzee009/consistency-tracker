import 'package:flutter/material.dart';
import '../../theme/motion.dart';
import '../../utils/motion_accessibility.dart';

/// Digit roll/slide for counters. See CURRENT_MODULE.md Step 17 for scope.
class AnimatedNumber extends StatefulWidget {
  final int value;
  final TextStyle? style;
  final Duration? duration;

  const AnimatedNumber({
    super.key,
    required this.value,
    this.style,
    this.duration,
  });

  @override
  State<AnimatedNumber> createState() => _AnimatedNumberState();
}

class _AnimatedNumberState extends State<AnimatedNumber> {
  @override
  Widget build(BuildContext context) {
    final accessibility = MotionAccessibility.of(context);
    if (accessibility.reduce) {
      return Text(widget.value.toString(), style: widget.style);
    }

    final effectiveDuration = accessibility.apply(widget.duration ?? Motion.medium);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: widget.value.toDouble()),
      duration: effectiveDuration,
      curve: Motion.standardEase,
      builder: (context, value, child) {
        return Text(value.round().toString(), style: widget.style);
      },
    );
  }
}
