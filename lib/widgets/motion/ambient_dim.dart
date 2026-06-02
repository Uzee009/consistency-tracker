import 'package:flutter/material.dart';
import '../../theme/motion.dart';
import '../../utils/motion_accessibility.dart';
import 'package:flutter/foundation.dart';

/// Dims/desaturates the UI when window is blurred or user is idle.
/// See CURRENT_MODULE.md Step 17 for scope.
class AmbientDim extends StatelessWidget {
  final Widget child;
  final ValueListenable<bool> windowFocused;
  final ValueListenable<bool> userActive;

  const AmbientDim({
    super.key,
    required this.child,
    required this.windowFocused,
    required this.userActive,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([windowFocused, userActive]),
      builder: (context, _) {
        final bool isDimmed = !windowFocused.value || !userActive.value;
        final double target = isDimmed ? 1.0 : 0.0;
        final accessibility = MotionAccessibility.of(context);

        if (accessibility.reduce) {
          return _buildWithSaturation(isDimmed ? 0.95 : 1.0);
        }

        return TweenAnimationBuilder<double>(
          duration: Motion.medium,
          curve: Motion.standardEase,
          tween: Tween<double>(begin: 0.0, end: target),
          builder: (context, value, child) {
            // value goes from 0.0 (active) to 1.0 (dimmed)
            final saturation = 1.0 - (value * 0.05);
            return _buildWithSaturation(saturation);
          },
          child: child,
        );
      },
    );
  }

  Widget _buildWithSaturation(double s) {
    final matrix = [
      0.2126 + 0.7874 * s, 0.7152 - 0.7152 * s, 0.0722 - 0.0722 * s, 0.0, 0.0,
      0.2126 - 0.2126 * s, 0.7152 + 0.2848 * s, 0.0722 - 0.0722 * s, 0.0, 0.0,
      0.2126 - 0.2126 * s, 0.7152 - 0.7152 * s, 0.0722 + 0.9278 * s, 0.0, 0.0,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ];
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(matrix),
      child: child,
    );
  }
}
