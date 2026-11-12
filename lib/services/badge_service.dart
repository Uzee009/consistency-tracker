import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
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
  int _eodMinute = 0;

  int get eodHour => _eodHour;
  int get eodMinute => _eodMinute;
  TimeOfDay get eodTime => TimeOfDay(hour: _eodHour, minute: _eodMinute);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _eodHour = prefs.getInt(DatabaseService.prefixedKey('badge_eod_hour')) ?? 20;
    _eodMinute = prefs.getInt(DatabaseService.prefixedKey('badge_eod_minute')) ?? 0;

    // Periodic evaluation every 60 seconds for time-of-day progression
    _evalTimer?.cancel();
    _evalTimer = Timer.periodic(const Duration(minutes: 1), (_) => evaluateBadge());
  }

  Future<void> setEodTime(TimeOfDay time) async {
    _eodHour = time.hour;
    _eodMinute = time.minute;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(DatabaseService.prefixedKey('badge_eod_hour'), time.hour);
    await prefs.setInt(DatabaseService.prefixedKey('badge_eod_minute'), time.minute);
    await evaluateBadge();
  }

  Future<void> setEodHour(int hour) async {
    await setEodTime(TimeOfDay(hour: hour, minute: _eodMinute));
  }

  /// Calculates whether and how the badge should show:
  /// - If count == 0: clear
  /// - Morning (5:00 AM - 11:59 AM): Calm Blue badge (#3B82F6)
  /// - Midday (12:00 PM - 3:59 PM): Amber / Yellow badge (#EAB308)
  /// - Late Afternoon (4:00 PM - EOD threshold): Orange badge (#F97316)
  /// - Evening / Night / Past EOD (>= EOD threshold or < 5:00 AM): Urgent Red badge (#EF4444)
  Future<void> updateBadge({
    required int pendingTaskCount,
  }) async {
    if (!Platform.isWindows) return;

    if (pendingTaskCount <= 0) {
      if (_lastCount != 0) {
        _lastCount = 0;
        _lastColor = null;
        try {
          await _channel.invokeMethod('clearBadge');
        } catch (_) {}
      }
      return;
    }

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final eodMinutes = _eodHour * 60 + _eodMinute;

    // Determine progressive color
    Color badgeColor;
    if (now.hour < 5 || currentMinutes >= eodMinutes) {
      badgeColor = const Color(0xFFEF4444); // Red (End of Day urgency or late night)
    } else if (now.hour >= 16) {
      badgeColor = const Color(0xFFF97316); // Orange (Late afternoon)
    } else if (now.hour >= 12) {
      badgeColor = const Color(0xFFEAB308); // Yellow (Midday)
    } else {
      badgeColor = const Color(0xFF3B82F6); // Blue (Fresh morning start)
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

  /// Sends a temporary preview badge to verify Windows taskbar badge integration
  Future<void> testBadge() async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod('setBadge', {
        'count': 3,
        'r': 239,
        'g': 68,
        'b': 68,
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
