import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'database_service.dart';
import 'connectivity_service.dart';

/// Represents information about an available application update.
class UpdateInfo {
  final String version;
  final String notes;
  final String downloadUrl;
  final String pageUrl;

  const UpdateInfo({
    required this.version,
    required this.notes,
    required this.downloadUrl,
    required this.pageUrl,
  });
}

/// Possible outcomes of an update check.
enum UpdateCheckResult {
  upToDate,
  updateAvailable,
  offline,
  error,
}

/// A service that checks for application updates via the GitHub Releases API.
class UpdateService {
  UpdateService._();

  /// The singleton instance of [UpdateService].
  static final UpdateService instance = UpdateService._();

  static const String _repo = 'Uzee009/consistency-tracker';
  static const int _checkIntervalHours = 6;

  /// A notifier that holds the [UpdateInfo] if an update is available.
  final ValueNotifier<UpdateInfo?> available = ValueNotifier<UpdateInfo?>(null);

  String? _currentVersion;

  /// Returns the current version of the application.
  String? get currentVersion => _currentVersion;

  /// Returns the current version of the application asynchronously.
  Future<String> getCurrentVersion() => _loadCurrentVersion();

  /// Loads and caches the current application version from platform info.
  Future<String> _loadCurrentVersion() async {
    if (_currentVersion != null) return _currentVersion!;
    final packageInfo = await PackageInfo.fromPlatform();
    _currentVersion = packageInfo.version;
    return _currentVersion!;
  }

  /// Checks for application updates.
  ///
  /// If [manual] is true, it bypasses connectivity checks and throttling.
  Future<UpdateCheckResult> checkForUpdate({bool manual = false}) async {
    try {
      final current = await _loadCurrentVersion();

      // Check connectivity for automatic checks
      if (!manual && ConnectivityService.instance.isOnline.value == false) {
        return UpdateCheckResult.offline;
      }

      final prefs = await SharedPreferences.getInstance();
      final lastCheckKey = DatabaseService.prefixedKey('update_last_check');
      final lastCheck = prefs.getInt(lastCheckKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Throttle automatic checks
      if (!manual && (now - lastCheck) < _checkIntervalHours * 3600 * 1000) {
        return available.value != null
            ? UpdateCheckResult.updateAvailable
            : UpdateCheckResult.upToDate;
      }

      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$_repo/releases/latest'),
        headers: {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'consistency-tracker-app',
        },
      ).timeout(const Duration(seconds: 10));

      // Always update last check timestamp after a network attempt
      await prefs.setInt(lastCheckKey, now);

      if (response.statusCode == 404) {
        available.value = null;
        return UpdateCheckResult.upToDate;
      }

      if (response.statusCode != 200) {
        return UpdateCheckResult.error;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final tagName = data['tag_name'] as String;
      final body = data['body'] as String? ?? '';
      final htmlUrl = data['html_url'] as String;
      final assets = data['assets'] as List<dynamic>;

      // Clean remote version string (strip 'v' and build metadata)
      var remoteVersion =
          tagName.startsWith('v') ? tagName.substring(1) : tagName;
      if (remoteVersion.contains('+')) {
        remoteVersion = remoteVersion.split('+').first;
      }

      if (!_isNewer(remoteVersion, current)) {
        available.value = null;
        return UpdateCheckResult.upToDate;
      }

      // Detect appropriate asset for current platform
      String? downloadUrl;
      for (final asset in assets) {
        final name = asset['name'] as String;
        final assetUrl = asset['browser_download_url'] as String;

        if (Platform.isLinux && name.endsWith('.tar.gz')) {
          downloadUrl = assetUrl;
          break;
        } else if (Platform.isWindows && name.endsWith('.zip')) {
          downloadUrl = assetUrl;
          break;
        } else if (Platform.isMacOS && name.endsWith('.dmg')) {
          downloadUrl = assetUrl;
          break;
        }
      }

      available.value = UpdateInfo(
        version: remoteVersion,
        notes: body,
        downloadUrl: downloadUrl ?? htmlUrl,
        pageUrl: htmlUrl,
      );

      return UpdateCheckResult.updateAvailable;
    } catch (e) {
      return UpdateCheckResult.error;
    }
  }

  /// Compares two semantic version strings.
  bool _isNewer(String remote, String current) {
    final remoteParts = remote.split('.');
    final currentParts = current.split('.');
    final length = remoteParts.length > currentParts.length
        ? remoteParts.length
        : currentParts.length;

    for (var i = 0; i < length; i++) {
      final r = i < remoteParts.length ? int.tryParse(remoteParts[i]) ?? 0 : 0;
      final c =
          i < currentParts.length ? int.tryParse(currentParts[i]) ?? 0 : 0;

      if (r > c) return true;
      if (r < c) return false;
    }
    return false;
  }

  /// Opens the download URL or the release page in the system browser.
  Future<void> openDownload() async {
    final info = available.value;
    if (info == null) return;

    try {
      final uri = Uri.parse(info.downloadUrl);
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(Uri.parse(info.pageUrl),
            mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(Uri.parse(info.pageUrl),
          mode: LaunchMode.externalApplication);
    }
  }

  /// Marks a specific version as dismissed by the user.
  Future<void> dismiss(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        DatabaseService.prefixedKey('update_dismissed'), version);
  }

  /// Checks if a specific version has been dismissed by the user.
  Future<bool> isDismissed(String version) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed =
        prefs.getString(DatabaseService.prefixedKey('update_dismissed'));
    return dismissed == version;
  }
}
