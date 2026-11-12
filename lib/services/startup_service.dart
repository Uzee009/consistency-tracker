import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';

class StartupService {
  StartupService._();
  static final StartupService instance = StartupService._();

  static const String _regKeyPath = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const String _appName = 'ConsistencyTracker';

  bool _isLaunchOnStartup = false;
  bool get isLaunchOnStartup => _isLaunchOnStartup;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isLaunchOnStartup = prefs.getBool(DatabaseService.prefixedKey('launch_on_startup')) ?? false;

    if (Platform.isWindows) {
      // Sync registry state with setting
      await _applyRegistryState(_isLaunchOnStartup);
    }
  }

  Future<void> setLaunchOnStartup(bool enable) async {
    _isLaunchOnStartup = enable;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(DatabaseService.prefixedKey('launch_on_startup'), enable);

    if (Platform.isWindows) {
      await _applyRegistryState(enable);
    }
  }

  Future<void> _applyRegistryState(bool enable) async {
    if (!Platform.isWindows) return;

    try {
      final exePath = Platform.resolvedExecutable;
      if (enable) {
        // Add to registry: reg add HKCU\Software\Microsoft\Windows\CurrentVersion\Run /v ConsistencyTracker /t REG_SZ /d "exePath" /f
        await Process.run('reg', [
          'add',
          _regKeyPath,
          '/v',
          _appName,
          '/t',
          'REG_SZ',
          '/d',
          '"$exePath"',
          '/f',
        ]);
      } else {
        // Remove from registry: reg delete HKCU\Software\Microsoft\Windows\CurrentVersion\Run /v ConsistencyTracker /f
        await Process.run('reg', [
          'delete',
          _regKeyPath,
          '/v',
          _appName,
          '/f',
        ]);
      }
    } catch (_) {}
  }
}

