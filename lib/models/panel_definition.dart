// lib/models/panel_definition.dart

import 'package:flutter/material.dart';
import '../controllers/dashboard_controller.dart';

typedef PanelContentBuilder = Widget Function(BuildContext context, DashboardController controller, BoxConstraints constraints);
typedef PanelActionsBuilder = List<Widget> Function(BuildContext context, DashboardController controller);

class PanelDefinition {
  final String id;
  final String title;
  final IconData icon;
  final String description;
  final PanelContentBuilder contentBuilder;
  final PanelActionsBuilder? actionsBuilder;
  
  // V7: Hard Minimum Constraints
  final double minWidth;
  final double minHeight;

  PanelDefinition({
    required this.id,
    required this.title,
    required this.icon,
    required this.description,
    required this.contentBuilder,
    required this.minWidth,
    required this.minHeight,
    this.actionsBuilder,
  });
}
