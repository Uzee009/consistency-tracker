import 'package:flutter/widgets.dart';

/// Motion design tokens. See CURRENT_MODULE.md Step 17 for scope.
class Motion {
  // Duration tokens
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration hero = Duration(milliseconds: 600);
  static const Duration ambientBreath = Duration(milliseconds: 2000);

  // Curve tokens
  static const Curve standardEase = Curves.easeOutCubic;
  static const Curve exitEase = Curves.easeInCubic;
  static const Curve emphasized = Curves.easeOutBack;
  static const Curve ambient = Curves.easeInOutSine;

  /// Returns a scaled duration based on speed factor.
  /// If speed <= 0, returns the original duration.
  static Duration scaled(Duration d, double speed) {
    if (speed <= 0) return d;
    return Duration(microseconds: (d.inMicroseconds / speed).round());
  }
}
