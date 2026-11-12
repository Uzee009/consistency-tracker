import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';

class BadgeService {
  BadgeService._();
  static final BadgeService instance = BadgeService._();

  static const MethodChannel _channel = MethodChannel('consistency_tracker/taskbar_badge');

  Timer? _evalTimer;
  int _lastCount = -1;
  Color? _lastColor;
  int _eodHour = 20; // 8 PM default

  int get eodHour => _eodHour;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _eodHour = prefs.getInt(DatabaseService.prefixedKey('badge_eod_hour')) ?? 20;

    // Periodic evaluation every 60 seconds for time-of-day progression
    _evalTimer?.cancel();
    _evalTimer = Timer.periodic(const Duration(minutes: 1), (_) => evaluateBadge());
  }

  Future<void> setEodHour(int hour) async {
    _eodHour = hour;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(DatabaseService.prefixedKey('badge_eod_hour'), hour);
    await evaluateBadge();
  }

  /// Calculates whether and how the badge should show:
  /// - If count == 0: clear
  /// - Before 12 PM: clear (fresh day start)
  /// - 12 PM - 3:59 PM: Yellow badge
  /// - 4 PM - (EOD - 1 minute): Orange badge
  /// - >= EOD hour (default 8 PM): Red badge
  Future<void> updateBadge({
    required int pendingTaskCount,
  }) async {
    if (!Platform.isWindows) return;

    final now = DateTime.now();
    final hour = now.hour;

    if (pendingTaskCount <= 0 || hour < 12) {
      if (_lastCount != 0) {
        _lastCount = 0;
        _lastColor = null;
        try {
          await _channel.invokeMethod('clearBadge');
        } catch (_) {}
      }
      return;
    }

    // Determine progressive color
    Color badgeColor;
    if (hour >= _eodHour) {
      badgeColor = const Color(0xFFEF4444); // Red (End of Day urgency)
    } else if (hour >= 16) {
      badgeColor = const Color(0xFFF97316); // Orange (Late afternoon)
    } else {
      badgeColor = const Color(0xFFEAB308); // Yellow (Midday)
    }

    if (_lastCount == pendingTaskCount && _lastColor == badgeColor) {
      return; // No change needed
    }

    _lastCount = pendingTaskCount;
    _lastColor = badgeColor;

    try {
      final argb = badgeColor.toARGB32();
      final r = (argb >> 16) & 0xFF;
      final g = (argb >> 8) & 0xFF;
      final b = argb & 0xFF;

      await _channel.invokeMethod('setBadge', {
        'count': pendingTaskCount,
        'r': r,
        'g': g,
        'b': b,
      });
    } catch (_) {}
  }

  Future<void> evaluateBadge() async {
    if (!Platform.isWindows) return;

    try {
      final today = DateTime.now();
      final dateFormatted = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
      
      final activeTasks = await DatabaseService.instance.getActiveTasksForDate(today);
      final record = await DatabaseService.instance.getDayRecord(dateFormatted);

      final completedIds = record?.completedTaskIds ?? [];
      final skippedIds = record?.skippedTaskIds ?? [];

      final pendingCount = activeTasks.where(
        (t) => !completedIds.contains(t.sid) && !skippedIds.contains(t.sid),
      ).length;

      await updateBadge(pendingTaskCount: pendingCount);
    } catch (_) {}
  }

  void dispose() {
    _evalTimer?.cancel();
  }
}
