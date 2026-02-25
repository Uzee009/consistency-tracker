import 'package:flutter/material.dart';
import '../models/task_model.dart';

enum VisualStyle { minimalist, vibrant }

class StyleService {
  static Color getPrimaryColor(VisualStyle style, bool isDark) {
    if (style == VisualStyle.vibrant) {
      return isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED); // Violet 400 : 600
    }
    return isDark ? Colors.white : const Color(0xFF09090B); // Zinc 950
  }

  static Color getDailyTaskBg(VisualStyle style, bool isDark) {
    if (style == VisualStyle.vibrant) {
      return isDark ? const Color(0xFF1E3A8A).withOpacity(0.3) : const Color(0xFFE0F2FE); // Blue 900 : 100
    }
    return isDark ? const Color(0xFF18181B) : const Color(0xFFF4F4F5); // Zinc 900 : 100
  }

  static Color getDailyTaskBorder(VisualStyle style, bool isDark) {
    if (style == VisualStyle.vibrant) {
      return isDark ? const Color(0xFF3B82F6) : const Color(0xFF7DD3FC); // Blue 500 : 300
    }
    return isDark ? Colors.white10 : Colors.black.withOpacity(0.05);
  }

  static Color getTempTaskBg(VisualStyle style, bool isDark) {
    if (style == VisualStyle.vibrant) {
      return isDark ? const Color(0xFF713F12).withOpacity(0.3) : const Color(0xFFFEF9C3); // Yellow 900 : 100
    }
    return isDark ? const Color(0xFF18181B) : const Color(0xFFF4F4F5);
  }

  static Color getTempTaskBorder(VisualStyle style, bool isDark) {
    if (style == VisualStyle.vibrant) {
      return isDark ? const Color(0xFFEAB308) : const Color(0xFFFDE047); // Yellow 500 : 300
    }
    return isDark ? Colors.white10 : Colors.black.withOpacity(0.05);
  }

  static Color getHeatmapBg(VisualStyle style, bool isDark) {
    if (style == VisualStyle.vibrant) {
      return isDark ? const Color(0xFF170D26) : const Color(0xFFFDF4FF); // Deep Purple : Fuchsia 50
    }
    return isDark ? const Color(0xFF09090B) : const Color(0xFFF4F4F5);
  }

  static Color getHeatmapEmptyCell(VisualStyle style, bool isDark) {
    if (style == VisualStyle.vibrant) {
      return isDark ? const Color(0xFF2D1B4E) : const Color(0xFFFAE8FF); // Dark Purple : Fuchsia 100
    }
    return isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
  }

  static Color getHeatmapHighlight(VisualStyle style, bool isDark) {
    if (style == VisualStyle.vibrant) {
      return isDark ? const Color(0xFF3B2166) : Colors.white; // Mid Purple
    }
    return isDark ? const Color(0xFF18181B) : Colors.white;
  }

  static Color getTaskItemBg(VisualStyle style, bool isDark, TaskType type) {
    if (style == VisualStyle.vibrant) {
      if (isDark) {
        return type == TaskType.daily 
            ? const Color(0xFF172554) // Blue 950
            : const Color(0xFF451A03); // Amber 950
      } else {
        return type == TaskType.daily 
            ? const Color(0xFFF0F9FF) // Blue 50
            : const Color(0xFFFEFCE8); // Yellow 50
      }
    }
    if (style == VisualStyle.minimalist && isDark) {
      return const Color(0xFF18181B); // Zinc 900
    }
    return Colors.white;
  }
}
