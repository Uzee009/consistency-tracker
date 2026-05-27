import 'package:flutter/material.dart';

enum SyncReadiness { ready, notSignedIn, unreachable }

SyncReadiness computeSyncReadiness({
  required bool serverReachable,
  required bool authed,
}) {
  if (!serverReachable) return SyncReadiness.unreachable;
  if (!authed) return SyncReadiness.notSignedIn;
  return SyncReadiness.ready;
}

Color syncStatusColor(SyncReadiness r) {
  switch (r) {
    case SyncReadiness.ready:
      return Colors.green;
    case SyncReadiness.notSignedIn:
      return Colors.orange;
    case SyncReadiness.unreachable:
      return Colors.red;
  }
}

String syncStatusTooltip(SyncReadiness r, {required bool authed}) {
  switch (r) {
    case SyncReadiness.ready:
      return 'Connected — your tasks sync automatically.';
    case SyncReadiness.notSignedIn:
      return 'Not signed in — sign in to sync across your devices.';
    case SyncReadiness.unreachable:
      return authed
          ? 'Signed in, but the sync server is unreachable. Changes are saved locally and will sync automatically when it\'s back.'
          : 'Offline — can\'t reach the sync server.';
  }
}
