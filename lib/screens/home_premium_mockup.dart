// lib/screens/home_premium_mockup.dart

import 'package:flutter/material.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/dashboard_layout_controller.dart';
import '../widgets/dashboard_grid_renderer.dart';
import '../widgets/user_menu.dart';
import '../widgets/panel_picker.dart';
import '../main.dart';

class HomePremiumMockup extends StatefulWidget {
  const HomePremiumMockup({super.key});

  @override
  State<HomePremiumMockup> createState() => _HomePremiumMockupState();
}

class _HomePremiumMockupState extends State<HomePremiumMockup> {
  final DashboardController _dataController = DashboardController();
  final DashboardLayoutController _layoutController = DashboardLayoutController();

  @override
  void initState() {
    super.initState();
    _dataController.initialize(DateTime.now());
  }

  @override
  void dispose() {
    _dataController.dispose();
    _layoutController.dispose();
    super.dispose();
  }

  void _toggleEditMode() {
    _layoutController.toggleEditMode();
  }
  
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_dataController, _layoutController]),
      builder: (context, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF09090B) : Colors.grey[50],
          body: Column(
            children: [
              _buildGlobalHeader(context),
              Divider(height: 1, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
              
              Expanded(
                child: _dataController.isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : DashboardGridRenderer(
                      layoutController: _layoutController,
                      dataController: _dataController,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGlobalHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 64, padding: const EdgeInsets.symmetric(horizontal: 20),
      color: isDark ? const Color(0xFF09090B) : Colors.white,
      child: Row(children: [
        const Text(
          'COMMAND CENTER',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 14),
        ),
        const Spacer(),
        if (_layoutController.isEditMode && _layoutController.totalPanels < 4)
          TextButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('ADD PANEL'),
            onPressed: () {
              showDialog(
                context: context, 
                builder: (context) => PanelPicker(layoutController: _layoutController),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
              textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ),
        const SizedBox(width: 12),
        _buildHeaderIconButton(
          context, 
          _layoutController.isEditMode ? Icons.check_circle_outline_rounded : Icons.edit_note_rounded, 
          _layoutController.isEditMode ? 'DONE' : 'CUSTOMIZE', 
          _layoutController.isEditMode ? Colors.green : Theme.of(context).colorScheme.onSurface, 
          _toggleEditMode
        ),
        const SizedBox(width: 12),
        UserMenu(
          currentUser: _dataController.currentUser, 
          onSettingsReturn: () => _dataController.initialize(_dataController.selectedDate),
        ),
      ]),
    );
  }

  Widget _buildHeaderIconButton(BuildContext context, IconData icon, String tooltip, Color color, VoidCallback onTap) {
    return Tooltip(
      message: tooltip, 
      child: Material(
        color: Colors.transparent, 
        borderRadius: BorderRadius.circular(10), 
        child: InkWell(
          onTap: onTap, 
          borderRadius: BorderRadius.circular(10), 
          child: Padding(
            padding: const EdgeInsets.all(8), 
            child: Icon(icon, color: color.withValues(alpha: 0.8), size: 18),
          ),
        ),
      ),
    );
  }
}
