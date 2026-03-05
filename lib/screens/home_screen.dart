// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/dashboard_layout_controller.dart';
import '../widgets/dashboard_grid_renderer.dart';
import '../widgets/user_menu.dart';
import '../screens/analytics_explorer_screen.dart';
import '../screens/settings_screen.dart';
import '../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DashboardController _dataController = DashboardController();
  final DashboardLayoutController _layoutController = DashboardLayoutController();
  int _activeTabIndex = 0; // 0: Dashboard, 1: Explorer, 2: Profile

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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_dataController, _layoutController]),
      builder: (context, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          body: Column(
            children: [
              // 1. GLOBAL HEADER (Centering Branding only)
              _buildGlobalHeader(context),
              Divider(height: 1, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
              
              // 2. INTERNAL NAVBAR (Left aligned above grid)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Row(
                  children: [
                    _buildInLayoutNavBar(isDark),
                    const Spacer(),
                    if (_activeTabIndex == 0) _buildCustomizeButton(context),
                  ],
                ),
              ),

              // 3. MAIN WORKSPACE
              Expanded(
                child: _dataController.isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : _buildActiveView(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveView() {
    if (_activeTabIndex == 1) {
      return const AnalyticsExplorerScreen();
    } else if (_activeTabIndex == 2) {
      return const SettingsScreen(isEmbedded: true);
    }
    
    // DEFAULT: DASHBOARD
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: DashboardGridRenderer(
        layoutController: _layoutController,
        dataController: _dataController,
      ),
    );
  }

  Widget _buildGlobalHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final date = _dataController.selectedDate;
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dayName = weekdays[date.weekday - 1];
    final dateStr = "${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}";
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20), // Increased vertical space
      color: isDark ? const Color(0xFF09090B) : Colors.white,
      child: Row(
        children: [
          // LEFT: LOGO
          SizedBox(
            width: 40,
            child: Icon(Icons.auto_graph_rounded, color: Theme.of(context).colorScheme.primary, size: 24),
          ),

          // CENTER: BRANDING (Expanded to fill and center text)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('CONSISTENCY TRACKER', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 4)),
                const SizedBox(height: 4),
                Text('$dayName, $dateStr'.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey[500], letterSpacing: 1)),
              ],
            ),
          ),
          
          // RIGHT: USER MENU
          SizedBox(
            width: 40,
            child: Align(
              alignment: Alignment.centerRight,
              child: UserMenu(
                currentUser: _dataController.currentUser,
                onSettingsReturn: () => _dataController.initialize(_dataController.selectedDate),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInLayoutNavBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildNavTab('DASHBOARD', Icons.dashboard_rounded, _activeTabIndex == 0, () => setState(() => _activeTabIndex = 0)),
          _buildNavTab('EXPLORER', Icons.explore_rounded, _activeTabIndex == 1, () => setState(() => _activeTabIndex = 1)),
          _buildNavTab('PROFILE', Icons.person_rounded, _activeTabIndex == 2, () => setState(() => _activeTabIndex = 2)),
        ],
      ),
    );
  }

  Widget _buildCustomizeButton(BuildContext context) {
    final bool isEdit = _layoutController.isEditMode;
    final Color color = isEdit ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface;

    return Material(
      color: isEdit ? color.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => _layoutController.toggleEditMode(),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(isEdit ? Icons.check_circle_rounded : Icons.dashboard_customize_rounded, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                isEdit ? 'FINISH' : 'CUSTOMIZE LAYOUT',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavTab(String label, IconData icon, bool isSelected, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? Colors.white12 : Colors.white) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2, offset: const Offset(0, 1))] : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600, color: isSelected ? Theme.of(context).colorScheme.onSurface : Colors.grey, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}
