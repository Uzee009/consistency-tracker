// lib/services/account_registry.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';

/// A registry of per-account last-access timestamps for idle account isolation.
/// Tracks when each account was last used to facilitate automatic cleanup
/// of dormant SQLite files after 30 days of inactivity.
class AccountRegistry {
  AccountRegistry._();
  static final AccountRegistry instance = AccountRegistry._();

  static const String _prefsKey = 'account_registry';
  static const Duration defaultTtl = Duration(days: 30);
  static const String _localId = '_local';

  String get _prefixedKey => DatabaseService.prefixedKey(_prefsKey);

  /// Returns the current registry as an immutable copy. Empty map if unset/malformed.
  Future<Map<String, int>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_prefixedKey);
    if (jsonString == null) return {};

    try {
      final Map<String, dynamic> decoded = json.decode(jsonString);
      return decoded.map((key, value) => MapEntry(key, value as int));
    } catch (e) {
      debugPrint('AccountRegistry: Failed to decode registry: $e');
      return {};
    }
  }

  /// Stamps `userId` with the current epoch-ms timestamp and persists.
  /// `userId` of null is treated as `_local`.
  Future<void> touch(String? userId) async {
    final id = userId ?? _localId;
    final registry = await read();
    registry[id] = DateTime.now().millisecondsSinceEpoch;
    await _save(registry);
  }

  /// Removes the entry for `userId` from the registry. No-op if absent.
  Future<void> remove(String userId) async {
    final registry = await read();
    if (registry.containsKey(userId)) {
      registry.remove(userId);
      await _save(registry);
    }
  }

  /// Returns the list of user ids whose last-access timestamp is older than `ttl`
  /// AND are not equal to `activeUserId`. Removes those entries from the registry
  /// before returning. Does NOT touch the filesystem — caller deletes the .db files.
  /// `activeUserId` of null means "no account is currently active".
  Future<List<String>> evictIdle({
    Duration ttl = defaultTtl,
    String? activeUserId,
  }) async {
    final registry = await read();
    final now = DateTime.now().millisecondsSinceEpoch;
    final threshold = now - ttl.inMilliseconds;

    final evictedIds = <String>[];
    final remainingRegistry = Map<String, int>.from(registry);

    registry.forEach((id, lastAccess) {
      // Evict if older than threshold AND not the currently active account.
      // _local follows the same rule if it's not the active one.
      if (id != activeUserId && lastAccess < threshold) {
        evictedIds.add(id);
        remainingRegistry.remove(id);
      }
    });

    if (evictedIds.isNotEmpty) {
      await _save(remainingRegistry);
      debugPrint('AccountRegistry: Evicted ${evictedIds.length} idle accounts: $evictedIds');
    }

    return evictedIds;
  }

  /// Persists the full registry map to SharedPreferences.
  Future<void> _save(Map<String, int> registry) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefixedKey, json.encode(registry));
  }
}
