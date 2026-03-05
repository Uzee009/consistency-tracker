// lib/widgets/panels/add_panel_placeholder.dart
import 'package:flutter/material.dart';

class AddPanelPlaceholder extends StatelessWidget {
  final VoidCallback onPressed;
  const AddPanelPlaceholder({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
          width: 2,
        ),
      ),
      child: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Add Panel'),
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }
}
