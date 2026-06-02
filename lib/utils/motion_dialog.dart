import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/motion.dart';
import 'motion_accessibility.dart';

/// A drop-in replacement for showDialog that adds backdrop blur and scale transitions.
Future<T?> showMotionDialog<T>({
  required BuildContext context,
  required Widget child,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'dialog',
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: Motion.base,
    pageBuilder: (ctx, a1, a2) => child,
    transitionBuilder: (ctx, a1, a2, child) {
      final reduce = MotionAccessibility.of(ctx).reduce;
      if (reduce) return Opacity(opacity: a1.value, child: child);
      
      final curved = CurvedAnimation(
        parent: a1,
        curve: Motion.standardEase,
        reverseCurve: Motion.exitEase,
      );
      
      return BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: curved.value * 8,
          sigmaY: curved.value * 8,
        ),
        child: Opacity(
          opacity: curved.value,
          child: Transform.scale(
            scale: 0.96 + (curved.value * 0.04),
            child: Transform.translate(
              offset: Offset(0, (1 - curved.value) * 8),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}
