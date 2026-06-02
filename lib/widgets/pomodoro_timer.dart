// lib/widgets/pomodoro_timer.dart

import 'package:flutter/material.dart';
import 'package:consistency_tracker_v1/controllers/dashboard_controller.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_icon_size.dart';

class PomodoroTimer extends StatefulWidget {
  final DashboardController controller;
  const PomodoroTimer({super.key, required this.controller});

  @override
  State<PomodoroTimer> createState() => _PomodoroTimerState();
}

class _PomodoroTimerState extends State<PomodoroTimer> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    // We use the controller for state
    final int seconds = controller.timerSecondsRemaining;
    final bool isRunning = controller.isTimerRunning;
    final String mode = controller.timerMode;
    final int goal = controller.todayRecord.pomodoroGoal;
    final int completed = controller.todayRecord.pomodoroSessionsCompleted;
    
    final accentColor = _getAccentColor(context, mode);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Stack(
        children: [
          // 1. MODE SELECTORS (Pinned Top Left)
          Positioned(
            top: 0,
            left: 0,
            child: Row(
              children: [
                _buildModeButton(context, 'Focus', 'focus', mode),
                const SizedBox(width: AppSpacing.xxs),
                _buildModeButton(context, 'Short', 'shortBreak', mode),
                const SizedBox(width: AppSpacing.xxs),
                _buildModeButton(context, 'Long', 'longBreak', mode),
              ],
            ),
          ),

          // 2. UTILITY CONTROLS (Pinned Top Right)
          Positioned(
            top: 0,
            right: 0,
            child: Row(
              children: [
                _buildHeaderControl(
                  context,
                  icon: Icons.refresh_rounded,
                  onPressed: controller.resetTimer,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(width: AppSpacing.xxs),
                _buildHeaderControl(
                  context,
                  icon: Icons.settings_outlined,
                  onPressed: () => _showSettingsDialog(context, controller),
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),

          // 3. MAIN CENTERED CONTENT
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: AppSpacing.xl), // Offset for the pinned controls
                MouseRegion(
                  onEnter: (_) => setState(() => _isHovering = true),
                  onExit: (_) => setState(() => _isHovering = false),
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: controller.toggleTimer,
                    behavior: HitTestBehavior.opaque,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity: _isHovering ? 0.2 : 1.0,
                          child: Text(
                            _formatTime(seconds),
                            style: TextStyle(
                              fontSize: 84,
                              fontWeight: FontWeight.w400,
                              letterSpacing: -2,
                              color: isRunning ? accentColor : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (_isHovering)
                          Icon(
                            isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 64,
                            color: accentColor.withValues(alpha: 0.8),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                // Session Progress Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(goal, (index) {
                    final isDone = index < completed;
                    return Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone ? accentColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(BuildContext context, String label, String modeId, String currentMode) {
    final isSelected = currentMode == modeId;
    final accentColor = _getAccentColor(context, currentMode);
    return GestureDetector(
      onTap: () => widget.controller.setTimerMode(modeId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: isSelected ? accentColor.withValues(alpha: 0.2) : Colors.transparent),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            color: isSelected ? accentColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderControl(BuildContext context, {required IconData icon, required VoidCallback onPressed, required Color color}) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(padding: const EdgeInsets.all(AppSpacing.xxs), child: Icon(icon, size: AppIconSize.md, color: color)),
      ),
    );
  }

  Color _getAccentColor(BuildContext context, String mode) {
    // Semantic mode accents
    switch (mode) {
      case 'focus': return Theme.of(context).colorScheme.primary;
      case 'shortBreak': return const Color(0xFF10B981);
      case 'longBreak': return const Color(0xFF60A5FA);
      default: return Theme.of(context).colorScheme.primary;
    }
  }

  String _formatTime(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  void _showSettingsDialog(BuildContext context, DashboardController controller) {
    final focusController = TextEditingController(text: (controller.timerDurations['focus']! ~/ 60).toString());
    final shortController = TextEditingController(text: (controller.timerDurations['shortBreak']! ~/ 60).toString());
    final longController = TextEditingController(text: (controller.timerDurations['longBreak']! ~/ 60).toString());
    final goalController = TextEditingController(text: controller.todayRecord.pomodoroGoal.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Timer Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDurationInput('Focus (mins)', focusController),
            _buildDurationInput('Short Break (mins)', shortController),
            _buildDurationInput('Long Break (mins)', longController),
            _buildDurationInput('Daily Session Goal', goalController),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              controller.updateTimerSettings(
                int.tryParse(focusController.text) ?? 25,
                int.tryParse(shortController.text) ?? 5,
                int.tryParse(longController.text) ?? 15,
                int.tryParse(goalController.text) ?? 4,
              );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationInput(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      ),
    );
  }
}
