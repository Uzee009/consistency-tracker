import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'badge_service.dart';

enum WindowMode {
  dashboard,
  widget,
}

class WindowModeService {
  WindowModeService._();
  static final WindowModeService instance = WindowModeService._();

  final ValueNotifier<WindowMode> modeNotifier = ValueNotifier(WindowMode.dashboard);
  final ValueNotifier<bool> isPinnedNotifier = ValueNotifier(true);

  bool get isWidgetMode => modeNotifier.value == WindowMode.widget;

  static const String _keyWidgetWidth = 'widget_window_width';
  static const String _keyWidgetHeight = 'widget_window_height';
  static const String _keyWidgetPosX = 'widget_window_pos_x';
  static const String _keyWidgetPosY = 'widget_window_pos_y';

  static const String _keyDashboardWidth = 'dashboard_window_width';
  static const String _keyDashboardHeight = 'dashboard_window_height';
  static const String _keyDashboardPosX = 'dashboard_window_pos_x';
  static const String _keyDashboardPosY = 'dashboard_window_pos_y';

  static const String _keyIsPinned = 'widget_is_pinned';

  Future<void> init() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      isPinnedNotifier.value = prefs.getBool(_keyIsPinned) ?? true;
    } catch (_) {}
  }

  Future<void> switchToWidget() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
    if (modeNotifier.value == WindowMode.widget) return;

    final prefs = await SharedPreferences.getInstance();

    try {
      // 1. Save current dashboard geometry if valid
      final dashSize = await windowManager.getSize();
      final dashPos = await windowManager.getPosition();
      if (dashSize.width >= 600 && dashSize.height >= 400) {
        await prefs.setDouble(_keyDashboardWidth, dashSize.width);
        await prefs.setDouble(_keyDashboardHeight, dashSize.height);
        await prefs.setDouble(_keyDashboardPosX, dashPos.dx);
        await prefs.setDouble(_keyDashboardPosY, dashPos.dy);
      }

      // 2. Load or default widget geometry (compact floating companion)
      final widgetWidth = prefs.getDouble(_keyWidgetWidth) ?? 340.0;
      final widgetHeight = prefs.getDouble(_keyWidgetHeight) ?? 480.0;
      final widgetPosX = prefs.getDouble(_keyWidgetPosX);
      final widgetPosY = prefs.getDouble(_keyWidgetPosY);

      // 3. Configure window constraints for widget mode (freely resizable)
      await windowManager.setMinimumSize(const Size(280, 240));
      await windowManager.setMaximumSize(const Size(-1, -1));
      await windowManager.setSize(Size(widgetWidth, widgetHeight));
      await windowManager.setResizable(true);

      if (widgetPosX != null && widgetPosY != null) {
        await windowManager.setPosition(Offset(widgetPosX, widgetPosY));
      }

      // 4. Frameless, shadow, keep visible on taskbar for badge, and pin
      await windowManager.setAsFrameless();
      await windowManager.setHasShadow(true);
      await windowManager.setSkipTaskbar(false); // Kept visible in taskbar so live badge overlay displays
      await windowManager.setAlwaysOnTop(isPinnedNotifier.value);
    } catch (_) {}

    modeNotifier.value = WindowMode.widget;
    // Refresh taskbar badge overlay on the new window state
    BadgeService.instance.evaluateBadge(force: true);
  }

  Future<void> switchToDashboard() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
    if (modeNotifier.value == WindowMode.dashboard) return;

    final prefs = await SharedPreferences.getInstance();

    try {
      // 1. Save current widget geometry
      final widgetSize = await windowManager.getSize();
      final widgetPos = await windowManager.getPosition();
      if (widgetSize.width <= 600 && widgetSize.height <= 800) {
        await prefs.setDouble(_keyWidgetWidth, widgetSize.width);
        await prefs.setDouble(_keyWidgetHeight, widgetSize.height);
        await prefs.setDouble(_keyWidgetPosX, widgetPos.dx);
        await prefs.setDouble(_keyWidgetPosY, widgetPos.dy);
      }

      // 2. Load or default dashboard geometry
      final dashWidth = prefs.getDouble(_keyDashboardWidth) ?? 1400.0;
      final dashHeight = prefs.getDouble(_keyDashboardHeight) ?? 900.0;
      final dashPosX = prefs.getDouble(_keyDashboardPosX);
      final dashPosY = prefs.getDouble(_keyDashboardPosY);

      // 3. Reset constraints and geometry for dashboard mode
      await windowManager.setMinimumSize(const Size(1250, 850));
      await windowManager.setMaximumSize(const Size(-1, -1)); // Unconstrained
      await windowManager.setSize(Size(dashWidth, dashHeight));

      if (dashPosX != null && dashPosY != null) {
        await windowManager.setPosition(Offset(dashPosX, dashPosY));
      } else {
        await windowManager.center();
      }

      // 4. Restore normal title bar, taskbar visibility, and unpin
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      await windowManager.setSkipTaskbar(false); // Visible in taskbar again
      await windowManager.setAlwaysOnTop(false);
    } catch (_) {}

    modeNotifier.value = WindowMode.dashboard;
    // Refresh taskbar badge overlay
    BadgeService.instance.evaluateBadge(force: true);
  }

  Future<void> toggleMode() async {
    if (modeNotifier.value == WindowMode.widget) {
      await switchToDashboard();
    } else {
      await switchToWidget();
    }
  }

  Future<void> togglePin() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
    final next = !isPinnedNotifier.value;
    isPinnedNotifier.value = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsPinned, next);
      if (isWidgetMode) {
        await windowManager.setAlwaysOnTop(next);
      }
    } catch (_) {}
  }

  Future<void> hideToTray() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
    try {
      await windowManager.hide();
    } catch (_) {}
  }

  Future<void> showAndFocus() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {}
  }

  Future<void> onWindowResized() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
    try {
      final size = await windowManager.getSize();
      final prefs = await SharedPreferences.getInstance();
      if (isWidgetMode) {
        await prefs.setDouble(_keyWidgetWidth, size.width);
        await prefs.setDouble(_keyWidgetHeight, size.height);
      } else {
        if (size.width >= 600 && size.height >= 400) {
          await prefs.setDouble(_keyDashboardWidth, size.width);
          await prefs.setDouble(_keyDashboardHeight, size.height);
        }
      }
    } catch (_) {}
  }

  Future<void> onWindowMoved() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
    try {
      final pos = await windowManager.getPosition();
      final prefs = await SharedPreferences.getInstance();
      if (isWidgetMode) {
        await prefs.setDouble(_keyWidgetPosX, pos.dx);
        await prefs.setDouble(_keyWidgetPosY, pos.dy);
      } else {
        await prefs.setDouble(_keyDashboardPosX, pos.dx);
        await prefs.setDouble(_keyDashboardPosY, pos.dy);
      }
    } catch (_) {}
  }
}

