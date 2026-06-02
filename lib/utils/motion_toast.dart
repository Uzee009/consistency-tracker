import 'package:flutter/material.dart';

/// Top-level helper to show a motion-consistent floating SnackBar.
void showMotionToast(
  BuildContext context,
  String message, {
  SnackBarAction? action,
  Duration? duration,
}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: duration ?? const Duration(seconds: 3),
      content: Text(message),
      action: action,
      elevation: 6,
    ),
  );
}
