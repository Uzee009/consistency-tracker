// lib/controllers/dashboard_layout_controller.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/panel_definition.dart';
import '../models/dashboard_slot.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/panels/task_panel.dart';
import '../widgets/panels/calendar_panel.dart';
import '../widgets/panels/graph_panel.dart';
import '../widgets/panels/focus_panel.dart';

class DashboardLayoutController extends ChangeNotifier {
  static const String _layoutPrefKey = 'dashboard_slot_layout_v4';
  static const String _ratiosPrefKey = 'dashboard_ratios_v4';

  bool isEditMode = false;
  DashboardSlot? hoverSlot;
  int taskTabIndex = 0;

  void setTaskTabIndex(int index) {
    if (taskTabIndex != index) {
      taskTabIndex = index;
      notifyListeners();
    }
  }

  Map<DashboardSlot, String?> _panelPositions = {
    DashboardSlot.topLeft: 'tasks',
    DashboardSlot.bottomLeft: 'tasks',
    DashboardSlot.topRight: 'calendar',
    DashboardSlot.bottomRight: 'graph',
  };

  Map<DashboardSlot, String?> get panelPositions => _panelPositions;

  int get totalPanels => _panelPositions.values.whereType<String>().toSet().length;

  double hRatio = 0.65;
  double lvRatio = 0.5;
  double rvRatio = 0.5;

  final Map<String, PanelDefinition> _panelRegistry = {};

  DashboardLayoutController() {
    _registerPanels();
    loadLayout();
  }

  void _registerPanels() {
    _panelRegistry['tasks'] = PanelDefinition(
      id: 'tasks', title: 'Habit Mastery', icon: Icons.check_circle_outline_rounded, description: 'Your daily and temporary habits.',
      minWidth: 420, minHeight: 400,
      contentBuilder: (context, controller, constraints) => TaskPanel(controller: controller, layoutController: this, constraints: constraints),
      actionsBuilder: (context, controller, layout) => TaskPanel.getActions(context, controller, this),
    );
    _panelRegistry['calendar'] = PanelDefinition(
      id: 'calendar', title: 'Consistency Log', icon: Icons.calendar_month_rounded, description: 'A heatmap of your consistency.',
      minWidth: 320, minHeight: 400,
      contentBuilder: (context, controller, constraints) => CalendarPanel(controller: controller, constraints: constraints),
      actionsBuilder: (context, controller, layout) => CalendarPanel.getActions(context, controller, this),
    );
    _panelRegistry['graph'] = PanelDefinition(
      id: 'graph', title: 'Performance Trends', icon: Icons.show_chart_rounded, description: 'Analytics and trends.',
      minWidth: 340, minHeight: 400,
      contentBuilder: (context, controller, constraints) => GraphPanel(controller: controller, constraints: constraints),
      actionsBuilder: (context, controller, layout) => GraphPanel.getActions(context, controller, this),
    );
    _panelRegistry['focus'] = PanelDefinition(
      id: 'focus', title: 'Focus Zone', icon: Icons.timer_rounded, description: 'Pomodoro timer to maintain focus.',
      minWidth: 280, minHeight: 400,
      contentBuilder: (context, controller, constraints) => FocusPanel(controller: controller, constraints: constraints),
      actionsBuilder: (context, controller, layout) => FocusPanel.getActions(context, controller, this),
    );
  }

  double getMinHeightForSlot(DashboardSlot slot) {
    final id = _panelPositions[slot];
    return _panelRegistry[id]?.minHeight ?? 400;
  }

  double getMinWidthForSlot(DashboardSlot slot) {
    final id = _panelPositions[slot];
    return _panelRegistry[id]?.minWidth ?? 300;
  }

  void updateHRatio(double delta, double totalWidth) {
    final double newRatio = (hRatio + (delta / totalWidth));
    final minWLeft = [getMinWidthForSlot(DashboardSlot.topLeft), getMinWidthForSlot(DashboardSlot.bottomLeft)].reduce((a, b) => a > b ? a : b);
    final minWRight = [getMinWidthForSlot(DashboardSlot.topRight), getMinWidthForSlot(DashboardSlot.bottomRight)].reduce((a, b) => a > b ? a : b);
    if (totalWidth * newRatio < minWLeft || totalWidth * (1 - newRatio) < minWRight) return;
    hRatio = newRatio.clamp(0.1, 0.9);
    notifyListeners();
  }

  void updateVRatio(double delta, double totalHeight, bool isLeft) {
    final double currentRatio = isLeft ? lvRatio : rvRatio;
    final double newRatio = (currentRatio + (delta / totalHeight));
    final slotTop = isLeft ? DashboardSlot.topLeft : DashboardSlot.topRight;
    final slotBottom = isLeft ? DashboardSlot.bottomLeft : DashboardSlot.bottomRight;
    final double minHTop = getMinHeightForSlot(slotTop);
    final double minHBottom = getMinHeightForSlot(slotBottom);
    if (totalHeight * newRatio < minHTop || totalHeight * (1 - newRatio) < minHBottom) return;
    if (isLeft) lvRatio = newRatio.clamp(0.1, 0.9);
    else rvRatio = newRatio.clamp(0.1, 0.9);
    notifyListeners();
  }

  Widget getWidgetForId(String id, DashboardController dataController, BuildContext context, BoxConstraints constraints) {
    return _panelRegistry[id]?.contentBuilder(context, dataController, constraints) ?? const Center(child: Text("Unknown Panel"));
  }

  List<Widget> getHeaderActionsForId(String id, DashboardController dataController, BuildContext context) {
    // V9 ACTION BUILDER FIX
    final panelDef = _panelRegistry[id];
    if (panelDef != null && panelDef.actionsBuilder != null) {
      return panelDef.actionsBuilder!(context, dataController, this);
    }
    return [];
  }

  void toggleEditMode() {
    isEditMode = !isEditMode;
    if (!isEditMode) { hoverSlot = null; saveLayout(); }
    notifyListeners();
  }

  void setHoverSlot(DashboardSlot? slot) { if (hoverSlot != slot) { hoverSlot = slot; notifyListeners(); } }

  void addPanel(DashboardSlot slot, String panelId) {
    if (_panelPositions.values.contains(panelId)) return;
    _panelPositions[slot] = panelId;
    saveLayout();
    notifyListeners();
  }

  void replacePanel(String oldPanelId, String newPanelId) {
    if (_panelPositions.values.contains(newPanelId)) return;
    _panelPositions.updateAll((key, value) => value == oldPanelId ? newPanelId : value);
    saveLayout();
    notifyListeners();
  }

  void removePanel(String panelId) {
    _panelPositions.updateAll((key, value) => value == panelId ? null : value);
    saveLayout();
    notifyListeners();
  }

  void movePanelToSlot(String panelId, DashboardSlot targetSlot) {
    DashboardSlot? oldSlot;
    _panelPositions.forEach((slot, id) { if (id == panelId) oldSlot = slot; });
    if (oldSlot != null) {
      final existingAtTarget = _panelPositions[targetSlot];
      _panelPositions[targetSlot] = panelId;
      _panelPositions[oldSlot!] = existingAtTarget;
    } else {
      _panelPositions[targetSlot] = panelId;
    }
    saveLayout();
    notifyListeners();
  }

  PanelDefinition? getDefinition(String? id) => _panelRegistry[id];

  List<PanelDefinition> getAvailablePanels() {
    final activeIds = _panelPositions.values.whereType<String>().toSet();
    return _panelRegistry.values.where((def) => !activeIds.contains(def.id)).toList();
  }

  Future<void> saveLayout() async {
    final prefs = await SharedPreferences.getInstance();
    final posMap = _panelPositions.map((k, v) => MapEntry(k.name, v));
    await prefs.setString(_layoutPrefKey, jsonEncode(posMap));
    await prefs.setString(_ratiosPrefKey, jsonEncode({'h': hRatio, 'lv': lvRatio, 'rv': rvRatio}));
  }

  Future<void> loadLayout() async {
    final prefs = await SharedPreferences.getInstance();
    final layoutJson = prefs.getString(_layoutPrefKey);
    if (layoutJson != null) {
      final decoded = jsonDecode(layoutJson) as Map<String, dynamic>;
      _panelPositions = decoded.map((k, v) => MapEntry(
        DashboardSlot.values.firstWhere((e) => e.name == k),
        v as String?,
      ));
    }
    final ratiosJson = prefs.getString(_ratiosPrefKey);
    if (ratiosJson != null) {
      final decoded = jsonDecode(ratiosJson);
      hRatio = decoded['h'] ?? 0.65;
      lvRatio = decoded['lv'] ?? 0.5;
      rvRatio = decoded['rv'] ?? 0.5;
    }
    notifyListeners();
  }
}
