import 'package:flutter/widgets.dart';
import '../theme/motion.dart';
import '../main.dart';

class MotionAccessibility {
  final bool reduce;       // true if OS disableAnimations OR speed is treated as off
  final double speed;      // user setting, after OS override (1.0 when reduce)
  final bool performanceMode;

  const MotionAccessibility({
    required this.reduce,
    required this.speed,
    required this.performanceMode,
  });

  static MotionAccessibility of(BuildContext context) {
    final disable = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final s = motionNotifier.value;
    return MotionAccessibility(
      reduce: disable,
      speed: disable ? 1.0 : s.speed,
      performanceMode: s.performanceMode,
    );
  }

  Duration apply(Duration d) => reduce ? const Duration(milliseconds: 50) : Motion.scaled(d, speed);
}
