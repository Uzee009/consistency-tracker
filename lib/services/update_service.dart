import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'database_service.dart';

/// Represents information about an available application update.
class UpdateInfo {
  final String version;
  final String notes;
  final String downloadUrl;
  final String pageUrl;
  final String? sha256;
  final String? assetName;

  const UpdateInfo({
    required this.version,
    required this.notes,
    required this.downloadUrl,
    required this.pageUrl,
    this.sha256,
    this.assetName,
  });
}

/// Possible outcomes of an update check.
enum UpdateCheckResult {
  upToDate,
  updateAvailable,
  offline,
  error,
}

enum UpdateStage { idle, downloading, verifying, applying, restarting, error }

class UpdateProgress {
  final UpdateStage stage;
  final double? pct; // 0..1 while downloading; null for other stages
  final String? message; // user-facing detail (especially on error)
  const UpdateProgress(this.stage, {this.pct, this.message});
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

  /// A notifier that holds the current update progress.
  final ValueNotifier<UpdateProgress> progress =
      ValueNotifier(const UpdateProgress(UpdateStage.idle));

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
      String? sha256;
      String? assetName;

      for (final asset in assets) {
        final name = asset['name'] as String;
        final assetUrl = asset['browser_download_url'] as String;
        final digest = asset['digest'] as String?;

        bool match = false;
        if (Platform.isLinux && name.endsWith('.tar.gz')) {
          match = true;
        } else if (Platform.isWindows && name.endsWith('.zip')) {
          match = true;
        } else if (Platform.isMacOS && name.endsWith('.dmg')) {
          match = true;
        }

        if (match) {
          downloadUrl = assetUrl;
          assetName = name;
          if (digest != null) {
            sha256 = digest.startsWith('sha256:')
                ? digest.substring(7).trim()
                : digest.trim();
          }
          break;
        }
      }

      available.value = UpdateInfo(
        version: remoteVersion,
        notes: body,
        downloadUrl: downloadUrl ?? htmlUrl,
        pageUrl: htmlUrl,
        sha256: sha256,
        assetName: assetName,
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

  /// Downloads the available update, applies it in place, and relaunches.
  /// Returns true if a relaunch was kicked off; false on handled failure.
  Future<bool> downloadAndApply() async {
    String? tempFilePath;
    try {
      final info = available.value;
      if (info == null) {
        progress.value = const UpdateProgress(UpdateStage.error,
            message: 'No update available');
        return false;
      }

      final paths = _getInstallPaths();
      final installParent = paths.$2;

      // Step 1: Writability probe (Linux/macOS only)
      if (Platform.isLinux || Platform.isMacOS) {
        final probePath = p.join(installParent,
            '.ct_probe_${DateTime.now().millisecondsSinceEpoch}');
        try {
          final probeFile = File(probePath);
          probeFile.writeAsStringSync('probe');
          probeFile.readAsStringSync();
          probeFile.deleteSync();
        } catch (e) {
          progress.value = const UpdateProgress(UpdateStage.error,
              message:
                  "Can't write to the install folder — move the app to your home folder or use Download manually");
          return false;
        }
      }

      // Step 2: Download
      progress.value = const UpdateProgress(UpdateStage.downloading, pct: 0);
      final client = http.Client();
      try {
        var request = http.Request('GET', Uri.parse(info.downloadUrl));
        request.headers['User-Agent'] = 'consistency-tracker-app';

        var response = await client.send(request);

        // Handle redirects
        int redirectCount = 0;
        while ([301, 302, 307, 308].contains(response.statusCode) &&
            redirectCount < 5) {
          final location = response.headers['location'];
          if (location == null) break;
          request = http.Request('GET', Uri.parse(location));
          request.headers['User-Agent'] = 'consistency-tracker-app';
          response = await client.send(request);
          redirectCount++;
        }

        if (response.statusCode != 200) {
          progress.value = UpdateProgress(UpdateStage.error,
              message: 'Download failed: ${response.statusCode}');
          return false;
        }

        final contentLength = response.contentLength;
        final tempDir = await getTemporaryDirectory();
        tempFilePath = p.join(tempDir.path, info.assetName ?? 'update.tmp');
        final file = File(tempFilePath);
        final sink = file.openWrite();

        int bytesDownloaded = 0;
        final stopwatch = Stopwatch()..start();

        await for (final chunk in response.stream) {
          sink.add(chunk);
          bytesDownloaded += chunk.length;

          if (contentLength != null && stopwatch.elapsedMilliseconds > 50) {
            progress.value = UpdateProgress(UpdateStage.downloading,
                pct: bytesDownloaded / contentLength);
            stopwatch.reset();
          }
        }
        await sink.close();
      } finally {
        client.close();
      }

      // Step 3: Verify
      if (info.sha256 != null) {
        progress.value = const UpdateProgress(UpdateStage.verifying);
        final bytes = await File(tempFilePath).readAsBytes();
        final digest = sha256.convert(bytes);
        if (digest.toString().toLowerCase() != info.sha256!.toLowerCase()) {
          progress.value = const UpdateProgress(UpdateStage.error,
              message: "Downloaded file failed integrity check");
          return false;
        }
      }

      // Step 4: Apply
      progress.value = const UpdateProgress(UpdateStage.applying);
      final newAppPath = await _applyUpdatePerOS(tempFilePath, info);

      // Step 5: Relaunch
      progress.value = const UpdateProgress(UpdateStage.restarting);
      await _relaunchPerOS(newAppPath);

      await Future.delayed(const Duration(milliseconds: 300));
      exit(0);
    } catch (e) {
      progress.value = UpdateProgress(UpdateStage.error, message: e.toString());
      if (tempFilePath != null) {
        try {
          File(tempFilePath).deleteSync();
        } catch (_) {}
      }
      return false;
    }
  }

  (String, String) _getInstallPaths() {
    final exe = Platform.resolvedExecutable;
    if (Platform.isLinux || Platform.isWindows) {
      final installDir = p.dirname(exe);
      final installParent = p.dirname(installDir);
      return (installDir, installParent);
    } else if (Platform.isMacOS) {
      final appPath = _findAppBundle(exe);
      if (appPath == null) {
        throw Exception(
            'App is not running from a .app bundle; cannot self-update');
      }
      final installParent = p.dirname(appPath);
      return (appPath, installParent);
    }
    throw UnsupportedError('Unsupported platform');
  }

  String? _findAppBundle(String exePath) {
    var current = exePath;
    while (current != p.dirname(current)) {
      if (p.basename(current).endsWith('.app')) {
        return current;
      }
      current = p.dirname(current);
    }
    return null;
  }

  Future<String> _applyUpdatePerOS(String tempFilePath, UpdateInfo info) async {
    final paths = _getInstallPaths();
    final installDir = paths.$1;
    final installParent = paths.$2;
    final exe = Platform.resolvedExecutable;

    if (Platform.isLinux) {
      final stageDir = p.join(
          installParent, '.ct_stage_${DateTime.now().millisecondsSinceEpoch}');
      await extractFileToDisk(tempFilePath, stageDir);

      final newExe = p.join(stageDir, p.basename(exe));
      if (!File(newExe).existsSync()) {
        try {
          Directory(stageDir).deleteSync(recursive: true);
        } catch (_) {}
        throw Exception(
            'Downloaded update is missing the application executable');
      }
      await Process.run('chmod', ['+x', newExe]);

      final oldPath =
          '$installDir.old.${DateTime.now().millisecondsSinceEpoch}';
      Directory(installDir).renameSync(oldPath);
      try {
        Directory(stageDir).renameSync(installDir);
      } catch (e) {
        try {
          Directory(oldPath).renameSync(installDir);
        } catch (_) {}
        rethrow;
      }
      final cleanupFile = File(p.join(installParent, '.ct_update_cleanup'));
      cleanupFile.writeAsStringSync('$oldPath\n', mode: FileMode.append);

      return p.join(installDir, p.basename(exe));
    } else if (Platform.isMacOS) {
      final appPath = installDir;
      final appParent = installParent;
      final tmpDir = await getTemporaryDirectory();
      final tmpMount = p.join(
          tmpDir.path, 'ct_mnt_${DateTime.now().millisecondsSinceEpoch}');

      await Process.run('hdiutil', [
        'attach',
        '-nobrowse',
        '-readonly',
        '-mountpoint',
        tmpMount,
        tempFilePath
      ]);
      final newApp = '$appPath.new';
      try {
        final apps = Directory(tmpMount)
            .listSync()
            .whereType<Directory>()
            .where((d) => p.basename(d.path).endsWith('.app'))
            .toList();
        if (apps.isEmpty) {
          throw Exception('No .app found inside the downloaded disk image');
        }
        if (Directory(newApp).existsSync()) {
          Directory(newApp).deleteSync(recursive: true);
        }
        final cp = await Process.run('cp', ['-R', apps.first.path, newApp]);
        if (cp.exitCode != 0) {
          throw Exception('Failed to copy app from disk image: ${cp.stderr}');
        }
      } finally {
        await Process.run('hdiutil', ['detach', tmpMount, '-force']);
      }
      final oldPath = '$appPath.old.${DateTime.now().millisecondsSinceEpoch}';
      Directory(appPath).renameSync(oldPath);
      try {
        Directory(newApp).renameSync(appPath);
      } catch (e) {
        try {
          Directory(oldPath).renameSync(appPath);
        } catch (_) {}
        rethrow;
      }
      await Process.run('xattr', ['-dr', 'com.apple.quarantine', appPath]);
      final cleanupFile = File(p.join(appParent, '.ct_update_cleanup'));
      cleanupFile.writeAsStringSync('$oldPath\n', mode: FileMode.append);
      return appPath;
    } else if (Platform.isWindows) {
      final tempDir = await getTemporaryDirectory();
      final stageDir = p.join(
          tempDir.path, 'ct_stage_${DateTime.now().millisecondsSinceEpoch}');
      await extractFileToDisk(tempFilePath, stageDir);

      final exeName = p.basename(exe);
      final helperPath = p.join(tempDir.path, 'update_helper.cmd');

      final script = '''
@echo off
:wait
tasklist /FI "IMAGENAME eq $exeName" | find /I "$exeName" >nul 2>&1 && (timeout /t 1 /nobreak >nul) && goto wait
robocopy "$stageDir" "$installDir" /E /MOVE /NFL /NDL /NJH /NJS /NC /NS >nul
start "" "$installDir\\$exeName"
del /Q "%~f0"
''';
      await File(helperPath).writeAsString(script);
      await Process.start('cmd', ['/c', helperPath],
          mode: ProcessStartMode.detached);

      return installDir;
    }
    throw UnsupportedError('Unsupported platform');
  }

  Future<void> _relaunchPerOS(String newAppPath) async {
    if (Platform.isWindows) return;

    if (Platform.isLinux) {
      await Process.start(newAppPath, [],
          mode: ProcessStartMode.detached,
          workingDirectory: p.dirname(newAppPath));
    } else if (Platform.isMacOS) {
      await Process.start('open', [newAppPath],
          mode: ProcessStartMode.detached);
    }
  }
}
