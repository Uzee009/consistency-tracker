// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/dashboard_layout_controller.dart';
import '../widgets/dashboard_grid_renderer.dart';
import '../widgets/user_menu.dart';
import '../widgets/app_logo.dart';
import '../screens/analytics_explorer_screen.dart';
import '../screens/settings_screen.dart';
import '../services/sync_service.dart';
import '../services/connectivity_service.dart';
import '../services/pocketbase_service.dart';
import '../widgets/sync_status.dart';

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
    SyncService.instance.dataChanged.addListener(_onSyncDataChanged);
  }

  void _onSyncDataChanged() {
    if (!mounted) return;
    _dataController.initialize(_dataController.selectedDate, showLoading: false);
  }

  @override
  void dispose() {
    SyncService.instance.dataChanged.removeListener(_onSyncDataChanged);
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
              // 1. GLOBAL HEADER
              _buildGlobalHeader(context),
              Divider(height: 1, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),

              // 2. INTERNAL NAVBAR (Left aligned above grid)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Row(
                  children: [
                    _buildInLayoutNavBar(isDark),
                    const Spacer(),
                    if (_activeTabIndex == 0) ...[
                      _buildCustomizeButton(context),
                    ],
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
      // V9: Pass controller to Explorer
      return AnalyticsExplorerScreen(controller: _dataController);
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

  Widget _buildMiniTimer(BuildContext context) {
    final mode = _dataController.timerMode;
    final color = mode == 'focus' ? const Color(0xFFE11D48) : (mode == 'shortBreak' ? const Color(0xFF10B981) : const Color(0xFF3B82F6));

    final int mins = _dataController.timerSecondsRemaining ~/ 60;
    final int secs = _dataController.timerSecondsRemaining % 60;
    final String timeStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_rounded, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            timeStr,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color, fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _dataController.toggleTimer,
            child: Icon(_dataController.isTimerRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 16, color: color),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _dataController.resetTimer,
            child: Icon(Icons.refresh_rounded, size: 12, color: color.withValues(alpha: 0.5)),
          ),
        ],
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
          const AppLogo(size: 36),
          const SizedBox(width: 16),

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

          // RIGHT: TIMER, REFRESH & USER MENU
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_dataController.isTimerRunning || _dataController.timerSecondsRemaining < _dataController.timerDurations[_dataController.timerMode]!) ...[
                _buildMiniTimer(context),
                const SizedBox(width: 16), // Margin between timer and refresh/user menu
              ],
              _buildSyncButton(context),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _dataController.initialize(_dataController.selectedDate),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text(
                  'REFRESH',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: UserMenu(
                    currentUser: _dataController.currentUser,
                    onSettingsReturn: () => _dataController.initialize(_dataController.selectedDate, showLoading: false),
                  ),
                ),
              ),
            ],
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? (Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.white) : Colors.transparent,
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


  Widget _buildSyncButton(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return ValueListenableBuilder<bool>(
      valueListenable: SyncService.instance.isSyncing,
      builder: (context, isSyncing, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: ConnectivityService.instance.isOnline,
          builder: (context, isOnline, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: PocketBaseService.instance.authState,
              builder: (context, isAuthed, _) {
                final readiness = computeSyncReadiness(serverReachable: isOnline, authed: isAuthed);
                final dotColor = syncStatusColor(readiness);
                final tooltipMsg = syncStatusTooltip(readiness, authed: isAuthed);

                return Tooltip(
                  message: tooltipMsg,
                  child: Material(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: isSyncing ? null : _handleSync,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
                            ),
                            const SizedBox(width: 8),
                            isSyncing
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: primary),
                                  )
                                : Icon(Icons.sync, size: 18, color: primary),
                            const SizedBox(width: 8),
                            Text(
                              isSyncing ? 'SYNCING…' : 'SYNC',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: primary, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _handleSync() async {
    final messenger = ScaffoldMessenger.of(context);
    final serverReachable = ConnectivityService.instance.isOnline.value;
    final isAuthed = PocketBaseService.instance.isAuthenticated;
    final readiness = computeSyncReadiness(serverReachable: serverReachable, authed: isAuthed);

    if (readiness == SyncReadiness.notSignedIn) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Not signed in — sign in to sync across your devices.'),
          action: SnackBarAction(
            label: 'SETTINGS',
            onPressed: () => setState(() => _activeTabIndex = 2),
          ),
        ),
      );
      return;
    }

    if (readiness == SyncReadiness.unreachable) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(syncStatusTooltip(readiness, authed: isAuthed)),
        ),
      );
      return;
    }

    final result = await SyncService.instance.sync();
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(result.summary)));
  }
}
