// lib/widgets/panel_picker.dart
import 'package:flutter/material.dart';
import '../controllers/dashboard_layout_controller.dart';
import '../models/panel_definition.dart';
import '../models/dashboard_slot.dart';

class PanelPicker extends StatelessWidget {
  final DashboardLayoutController layoutController;
  final DashboardSlot? targetSlot;
  final String? replacePanelId; // Target ID for replacement

  const PanelPicker({
    super.key, 
    required this.layoutController,
    this.targetSlot,
    this.replacePanelId,
  });

  @override
  Widget build(BuildContext context) {
    final availablePanels = layoutController.getAvailablePanels();

    return AlertDialog(
      title: Text(replacePanelId != null ? 'Replace Panel' : 'Add Panel'),
      content: SizedBox(
        width: 350,
        height: 400,
        child: availablePanels.isEmpty
            ? const Center(child: Text('No other panels available.'))
            : ListView.builder(
                itemCount: availablePanels.length,
                itemBuilder: (context, index) {
                  final panelDef = availablePanels[index];
                  return ListTile(
                    leading: Icon(panelDef.icon, color: Theme.of(context).colorScheme.primary),
                    title: Text(panelDef.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(panelDef.description, style: const TextStyle(fontSize: 11)),
                    onTap: () {
                      if (replacePanelId != null) {
                        layoutController.replacePanel(replacePanelId!, panelDef.id);
                      } else if (targetSlot != null) {
                        layoutController.addPanel(targetSlot!, panelDef.id);
                      }
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      ],
    );
  }
}
