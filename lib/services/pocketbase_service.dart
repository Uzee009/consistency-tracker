// lib/services/pocketbase_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';

class PocketBaseService {
  static final PocketBaseService instance = PocketBaseService._constructor();

  late PocketBase client;

  String _serverUrl = 'https://consistancy.duckdns.org';

  final ValueNotifier<bool> authState = ValueNotifier(false);

  /// Bumped whenever `client` is (re)built, so listeners can re-establish
  /// realtime subscriptions.
  final ValueNotifier<int> clientRevision = ValueNotifier<int>(0);

  StreamSubscription<AuthStoreEvent>? _authSub;

  PocketBaseService._constructor();

  /// Initialize the service: load saved server URL and restore auth token.
  /// Token is persisted via AsyncAuthStore backed by shared_preferences.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Load saved server URL
    _serverUrl = prefs.getString(DatabaseService.prefixedKey('sync_server_url')) ?? 'https://consistancy.duckdns.org';

    // Create AsyncAuthStore to persist token to shared_preferences
    final store = AsyncAuthStore(
      save: (String data) async => prefs.setString(DatabaseService.prefixedKey('pb_auth'), data),
      initial: prefs.getString(DatabaseService.prefixedKey('pb_auth')),
    );

    // Create PocketBase client with persisted auth store
    client = PocketBase(_serverUrl, authStore: store);

    // Subscribe to auth state changes
    _subscribeToAuthChanges();

    // Set initial auth state
    authState.value = client.authStore.isValid;

    clientRevision.value++;
  }

  /// Subscribe to auth store changes (called on init and after setServerUrl).
  void _subscribeToAuthChanges() {
    _authSub = client.authStore.onChange.listen((event) {
      authState.value = client.authStore.isValid;
    });
  }

  /// Whether the user is currently authenticated.
  bool get isAuthenticated => client.authStore.isValid;

  /// Get the current user's email, or null if not authenticated.
  String? get userEmail {
    if (!isAuthenticated) return null;
    final record = client.authStore.record;
    return record?.getStringValue('email');
  }

  /// Log in with email and password.
  /// Throws an exception if login fails.
  Future<void> login(String email, String password) async {
    try {
      await client.collection('users').authWithPassword(email, password);
      authState.value = true;
    } catch (e) {
      authState.value = false;
      rethrow;
    }
  }

  /// Create a new account, then sign in. v1: no email verification.
  /// Throws on failure (e.g. email already in use, password too short).
  Future<void> signUp(String email, String password) async {
    await client.collection('users').create(body: {
      'email': email,
      'password': password,
      'passwordConfirm': password,
    });
    // PocketBase does not auto-authenticate on create; sign in explicitly.
    await login(email, password);
  }

  /// Log out the current user.
  Future<void> logout() async {
    client.authStore.clear();
    authState.value = false;
  }

  Future<void> tryDevAutoLogin() async {
    const dbName = String.fromEnvironment('DATABASE_NAME');
    const email = String.fromEnvironment('SYNC_DEV_EMAIL');
    const password = String.fromEnvironment('SYNC_DEV_PASSWORD');
    // Only in dev mode, only if creds are provided, only if not already signed in.
    if (dbName != 'consistency_tracker_dev.db') return;
    if (email.isEmpty || password.isEmpty) return;
    if (isAuthenticated) return;
    try {
      await login(email, password);
    } catch (e) {
      // Local-first: server may be offline/unreachable. Never throw from startup.
      debugPrint('Dev auto-login skipped: $e');
    }
  }

  /// Set a new server URL and reinitialize the client.
  /// Cancels the old onChange subscription and re-subscribes on the new client.
  Future<void> setServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(DatabaseService.prefixedKey('sync_server_url'), url);

    // Clear per-collection pull cursors so the new server does a clean full pull.
    await DatabaseService.instance.clearSyncCursors();

    _serverUrl = url;

    // Cancel the old subscription
    _authSub?.cancel();

    // Reinitialize the client with the new URL (preserving auth store)
    client = PocketBase(url, authStore: client.authStore);

    // Re-subscribe to auth changes on the new client
    _subscribeToAuthChanges();

    // Update auth state after URL change
    authState.value = client.authStore.isValid;

    clientRevision.value++;
  }

  /// Get the current server URL.
  String get serverUrl => _serverUrl;
}
