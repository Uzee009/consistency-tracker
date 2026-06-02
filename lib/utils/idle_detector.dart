import 'dart:async';
import 'package:flutter/foundation.dart';

/// Notifies when the user is active/idle. See CURRENT_MODULE.md Step 17.
class IdleDetector {
  static final IdleDetector instance = IdleDetector._();
  IdleDetector._();

  static const Duration timeout = Duration(minutes: 5);
  Timer? _timer;
  
  /// Global notifier injected into main.dart
  late ValueNotifier<bool> userActiveNotifier;

  void initialize(ValueNotifier<bool> notifier) {
    userActiveNotifier = notifier;
    touch();
  }

  void touch() {
    userActiveNotifier.value = true;
    _timer?.cancel();
    _timer = Timer(timeout, () => userActiveNotifier.value = false);
  }

  void dispose() {
    _timer?.cancel();
  }
}
