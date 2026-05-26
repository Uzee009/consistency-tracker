// lib/services/connectivity_service.dart

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'pocketbase_service.dart';

class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._constructor();

  final Connectivity _connectivity = Connectivity();
  final ValueNotifier<bool> isOnline = ValueNotifier(false);

  ConnectivityService._constructor();

  /// Initialize the service: check connectivity now and subscribe to changes.
  Future<void> init() async {
    // Check initial state
    await checkNow();

    // Subscribe to connectivity changes
    _connectivity.onConnectivityChanged.listen((event) {
      // Re-check health on connectivity state change
      checkNow();
    });
  }

  /// Perform an on-demand health check against the PocketBase server.
  /// Updates the [isOnline] notifier and returns the result.
  /// Note: Depends on PocketBaseService being initialized first (guaranteed by main.dart ordering).
  Future<bool> checkNow() async {
    try {
      final serverUrl =
          '${PocketBaseService.instance.serverUrl}/api/health';
      final response = await http
          .get(Uri.parse(serverUrl))
          .timeout(const Duration(seconds: 5));

      final online = response.statusCode == 200;
      isOnline.value = online;
      return online;
    } catch (e) {
      isOnline.value = false;
      return false;
    }
  }
}
