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

Color syncStatusColor(SyncReadiness r, ColorScheme cs) {
  switch (r) {
    case SyncReadiness.ready:
      return const Color(0xFF10B981); // semantic success green — keep as constant since ColorScheme has no success slot
    case SyncReadiness.notSignedIn:
      return cs.tertiary;
    case SyncReadiness.unreachable:
      return cs.error;
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
