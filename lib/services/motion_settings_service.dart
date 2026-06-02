import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';

class MotionSettings {
  final double speed;
  final bool performanceMode;

  const MotionSettings({
    this.speed = 1.0,
    this.performanceMode = false,
  });

  MotionSettings copyWith({
    double? speed,
    bool? performanceMode,
  }) {
    return MotionSettings(
      speed: speed ?? this.speed,
      performanceMode: performanceMode ?? this.performanceMode,
    );
  }
}

class MotionSettingsService {
  static const _kSpeed = 'motion_speed';
  static const _kPerf = 'motion_perf_mode';

  static Future<MotionSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final speed = prefs.getDouble(DatabaseService.prefixedKey(_kSpeed)) ?? 1.0;
    final perf = prefs.getBool(DatabaseService.prefixedKey(_kPerf)) ?? false;
    
    return MotionSettings(
      speed: speed.clamp(0.5, 2.0),
      performanceMode: perf,
    );
  }

  static Future<void> save(MotionSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(DatabaseService.prefixedKey(_kSpeed), s.speed);
    await prefs.setBool(DatabaseService.prefixedKey(_kPerf), s.performanceMode);
  }
}
