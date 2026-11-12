import 'dart:io';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

class SystemTrayService {
  SystemTrayService._();
  static final SystemTrayService instance = SystemTrayService._();

  final SystemTray _systemTray = SystemTray();
  bool _initialized = false;

  Future<void> init() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
    if (_initialized) return;

    try {
      const String iconPath = 'assets/logos/logo_dark.ico';

      await _systemTray.initSystemTray(
        title: 'Consistency Tracker',
        iconPath: iconPath,
        toolTip: 'Consistency Tracker',
      );

      await _buildMenu();

      // Handle left click on tray icon -> Toggle window visibility
      _systemTray.registerSystemTrayEventHandler((eventName) async {
        if (eventName == 'leftMouseDown' || eventName == 'click') {
          final isVisible = await windowManager.isVisible();
          if (isVisible) {
            await windowManager.hide();
          } else {
            await windowManager.show();
            await windowManager.focus();
          }
        } else if (eventName == 'rightMouseDown' || eventName == 'rightClick') {
          await _systemTray.popUpContextMenu();
        }
      });

      _initialized = true;
    } catch (_) {
      // Tray initialization safe fallback
    }
  }

  Future<void> _buildMenu() async {
    final List<MenuItemBase> menuItems = [
      MenuItem(
        label: 'Open Dashboard',
        onClicked: () async {
          await windowManager.show();
          await windowManager.focus();
        },
      ),
      MenuSeparator(),
      MenuItem(
        label: 'Quit Consistency Tracker',
        onClicked: () async {
          await windowManager.destroy();
        },
      ),
    ];

    await _systemTray.setContextMenu(menuItems);
  }
}
