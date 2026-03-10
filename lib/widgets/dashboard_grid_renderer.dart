// lib/widgets/dashboard_grid_renderer.dart

import 'package:flutter/material.dart';
import '../controllers/dashboard_layout_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../models/dashboard_slot.dart';
import '../models/panel_definition.dart';
import '../widgets/panels/add_panel_placeholder.dart';
import '../widgets/panel_picker.dart';
import '../services/style_service.dart';
import '../main.dart';

class DashboardGridRenderer extends StatelessWidget {
  final DashboardLayoutController layoutController;
  final DashboardController dataController;

  const DashboardGridRenderer({
    super.key,
    required this.layoutController,
    required this.dataController,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth;
        final double totalHeight = constraints.maxHeight;

        final bool leftColEmpty = _isColEmpty([DashboardSlot.topLeft, DashboardSlot.bottomLeft]);
        final bool rightColEmpty = _isColEmpty([DashboardSlot.topRight, DashboardSlot.bottomRight]);

        if (leftColEmpty && rightColEmpty) {
          return _buildSlotWrapper(context, DashboardSlot.topLeft, null);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // LEFT COLUMN
            if (!leftColEmpty || layoutController.isEditMode)
              Expanded(
                flex: leftColEmpty ? 0 : (layoutController.hRatio * 100).toInt(),
                child: _buildColumn(context, [DashboardSlot.topLeft, DashboardSlot.bottomLeft], true, totalHeight),
              ),

            // DIVIDER
            if ((!leftColEmpty && !rightColEmpty) || layoutController.isEditMode)
              _buildVerticalDivider(context, totalWidth),

            // RIGHT COLUMN
            if (!rightColEmpty || layoutController.isEditMode)
              Expanded(
                flex: rightColEmpty ? 0 : ((1.0 - layoutController.hRatio) * 100).toInt(),
                child: _buildColumn(context, [DashboardSlot.topRight, DashboardSlot.bottomRight], false, totalHeight),
              ),
          ],
        );
      },
    );
  }

  bool _isColEmpty(List<DashboardSlot> slots) {
    if (layoutController.isEditMode) return false;
    return layoutController.panelPositions[slots[0]] == null &&
           layoutController.panelPositions[slots[1]] == null;
  }

  Widget _buildColumn(BuildContext context, List<DashboardSlot> slots, bool isLeft, double totalHeight) {
    final String? idA = layoutController.panelPositions[slots[0]];
    final String? idB = layoutController.panelPositions[slots[1]];

    bool showA = idA != null || layoutController.isEditMode;
    bool showB = idB != null || layoutController.isEditMode;

    if (showA && showB) {
      if (idA != null && idA == idB && !layoutController.isEditMode) {
        return _buildSlotWrapper(context, slots[0], idA);
      }

      final ratio = isLeft ? layoutController.lvRatio : layoutController.rvRatio;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: (ratio * 100).toInt(),
            child: _buildSlotWrapper(context, slots[0], idA),
          ),
          _buildHorizontalDivider(context, totalHeight, isLeft),
          Expanded(
            flex: ((1.0 - ratio) * 100).toInt(),
            child: _buildSlotWrapper(context, slots[1], idB),
          ),
        ],
      );
    } else if (showA) {
      return _buildSlotWrapper(context, slots[0], idA);
    } else if (showB) {
      return _buildSlotWrapper(context, slots[1], idB);
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildSlotWrapper(BuildContext context, DashboardSlot slot, String? panelId) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        layoutController.setHoverSlot(slot);
        return true;
      },
      onLeave: (details) => layoutController.setHoverSlot(null),
      onAcceptWithDetails: (details) {
        layoutController.movePanelToSlot(details.data, slot);
        layoutController.setHoverSlot(null);
      },
      builder: (context, candidateData, rejectedData) {
        final bool isHovered = layoutController.hoverSlot == slot;
        final bool isEdit = layoutController.isEditMode;

        return Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isHovered 
                  ? Theme.of(context).colorScheme.primary 
                  : (isEdit ? Colors.grey.withValues(alpha: 0.2) : Colors.transparent),
              width: isHovered ? 2 : 1,
            ),
            color: isHovered ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05) : Colors.transparent,
          ),
          child: panelId != null 
              ? _buildDraggablePanel(context, slot, panelId)
              : (isEdit ? _buildPlaceholder(context, slot) : const SizedBox.shrink()),
        );
      },
    );
  }

  Widget _buildDraggablePanel(BuildContext context, DashboardSlot slot, String panelId) {
    final def = layoutController.getDefinition(panelId);
    if (def == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    
    // V6: Dynamic drag pill colors
    // We force absolute contrast in Dark Mode to avoid invisible text.
    final Color bgColor = isDark ? const Color(0xFF18181B) : primary;
    final Color contentColor = isDark ? Colors.white : (bgColor.computeLuminance() > 0.5 ? Colors.black : Colors.white);

    return Draggable<String>(
      data: panelId,
      maxSimultaneousDrags: layoutController.isEditMode ? 1 : 0,
      feedback: Material(
        elevation: 10,
        borderRadius: BorderRadius.circular(24),
        color: Colors.transparent,
        child: Container(
          width: 300,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? Colors.white24 : Colors.transparent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(def.icon, color: contentColor, size: 16),
              const SizedBox(width: 12),
              Text(
                def.title, 
                style: TextStyle(
                  color: contentColor, 
                  fontWeight: FontWeight.bold, 
                  fontSize: 12,
                  decoration: TextDecoration.none, // V6: Fix for potential text styling leaks
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.1,
        child: _buildPanelShell(context, def),
      ),
      child: _buildPanelShell(context, def),
    );
  }

  Widget _buildPanelShell(BuildContext context, PanelDefinition def, {bool isFeedback = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEdit = layoutController.isEditMode;
    final style = styleNotifier.value;

    // V6: Seamless base color
    final bgColor = StyleService.getPanelBaseBg(
      def.id, 
      style, 
      isDark, 
      taskTabIndex: layoutController.taskTabIndex
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          // PANEL HEADER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
            child: Row(
              children: [
                if (isEdit) ...[
                  const Icon(Icons.drag_indicator_rounded, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                ],
                Icon(def.icon, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                const SizedBox(width: 12),
                Text(def.title.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                const Spacer(),
                ...layoutController.getHeaderActionsForId(def.id, dataController, context),
                if (isEdit) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => layoutController.removePanel(def.id),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, size: 10, color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
          // ADAPTIVE CONTENT
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0), // Reduced from 16.0
              child: ClipRect(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Opacity(
                      opacity: isEdit ? 0.6 : 1.0,
                      child: layoutController.getWidgetForId(def.id, dataController, context, constraints),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context, DashboardSlot slot) {
    return AddPanelPlaceholder(
      onPressed: () {
        showDialog(
          context: context, 
          builder: (context) => PanelPicker(
            layoutController: layoutController,
            targetSlot: slot,
          ),
        );
      },
    );
  }

  Widget _buildVerticalDivider(BuildContext context, double totalWidth) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        onPanUpdate: (d) => layoutController.updateHRatio(d.delta.dx, totalWidth),
        child: Container(
          width: 8,
          color: Colors.transparent,
          child: Center(
            child: Container(width: 2, height: 40, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(1))),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalDivider(BuildContext context, double totalHeight, bool isLeft) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpDown,
      child: GestureDetector(
        onPanUpdate: (d) => layoutController.updateVRatio(d.delta.dy, totalHeight, isLeft),
        child: Container(
          height: 8,
          color: Colors.transparent,
          child: Center(
            child: Container(height: 2, width: 40, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(1))),
          ),
        ),
      ),
    );
  }
}
