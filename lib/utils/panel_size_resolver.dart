// lib/utils/panel_size_resolver.dart

import 'package:flutter/material.dart';

enum PanelSize {
  compact,
  medium,
  large,
}

class PanelSizeResolver {
  static PanelSize resolve(BoxConstraints c) {
    // Height-based resolution
    if (c.maxHeight >= 420) return PanelSize.large;
    if (c.maxHeight >= 300) return PanelSize.medium;
    return PanelSize.compact;
  }

  static bool isCompactWidth(BoxConstraints c) => c.maxWidth < 350;
}
