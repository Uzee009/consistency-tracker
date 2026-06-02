import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../theme/motion.dart';
import '../../utils/motion_accessibility.dart';

/// Subtle time-of-day background drift.
/// See CURRENT_MODULE.md Step 17 for scope.
class ReactiveBackground extends StatefulWidget {
  final Widget child;

  const ReactiveBackground({super.key, required this.child});

  @override
  State<ReactiveBackground> createState() => _ReactiveBackgroundState();
}

class _ReactiveBackgroundState extends State<ReactiveBackground> {
  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accessibility = MotionAccessibility.of(context);
    if (accessibility.reduce || accessibility.performanceMode) {
      return widget.child;
    }

    // Phase 0.0 at 5am, 1.0 at 5am next day.
    final double hour = _now.hour + (_now.minute / 60.0);
    double phase = (hour - 5.0) / 24.0;
    if (phase < 0) phase += 1.0;

    final primary = Theme.of(context).colorScheme.primary;
    final hsl = HSLColor.fromColor(primary);

    // Subtle hue shift (+/- 3 degrees) and saturation (+/- 5%)
    final hueShift = 3.0 * math.sin(phase * 2.0 * math.pi);
    final satShift = 0.05 * math.cos(phase * 2.0 * math.pi);

    final color1 = hsl.withHue((hsl.hue + hueShift) % 360.0)
                      .withSaturation((hsl.saturation + satShift).clamp(0.0, 1.0))
                      .toColor();
    
    final color2 = hsl.withHue((hsl.hue - hueShift) % 360.0)
                      .withSaturation((hsl.saturation - satShift).clamp(0.0, 1.0))
                      .toColor();

    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedContainer(
            duration: accessibility.apply(Motion.slow),
            curve: Motion.standardEase,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color1.withValues(alpha: 0.04),
                  color2.withValues(alpha: 0.04),
                ],
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}
