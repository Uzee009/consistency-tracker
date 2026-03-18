// lib/widgets/pomodoro_timer.dart

import 'package:flutter/material.dart';
import 'package:consistency_tracker_v1/controllers/dashboard_controller.dart';

class PomodoroTimer extends StatelessWidget {
  final DashboardController controller;
  const PomodoroTimer({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    // V9: We now use the controller for ALL state
    final int seconds = controller.timerSecondsRemaining;
    final bool isRunning = controller.isTimerRunning;
    final String mode = controller.timerMode;
    final int goal = controller.todayRecord.pomodoroGoal;
    final int completed = controller.todayRecord.pomodoroSessionsCompleted;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Mode Selector
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildModeButton(context, 'Focus', 'focus', mode == 'focus'),
              _buildModeButton(context, 'Short Break', 'shortBreak', mode == 'shortBreak'),
              _buildModeButton(context, 'Long Break', 'longBreak', mode == 'longBreak'),
            ],
          ),
        ),
        const SizedBox(height: 32),
        
        // Timer Display
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 180,
              height: 180,
              child: CircularProgressIndicator(
                value: seconds / (controller.timerDurations[mode] ?? 1),
                strokeWidth: 8,
                backgroundColor: Colors.black.withValues(alpha: 0.05),
                color: _getModeColor(mode),
                strokeCap: StrokeCap.round,
              ),
            ),
            Column(
              children: [
                Text(
                  _formatTime(seconds),
                  style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: -1),
                ),
                Text(
                  mode.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey[500], letterSpacing: 1),
                ),
              ],
            ),
          ],
        ),
        
        const SizedBox(height: 32),
        
        // Controls
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildRoundButton(
              icon: Icons.settings_rounded,
              onPressed: () => _showSettingsDialog(context),
            ),
            const SizedBox(width: 24),
            _buildPlayButton(isRunning),
            const SizedBox(width: 24),
            _buildRoundButton(
              icon: Icons.refresh_rounded,
              onPressed: controller.resetTimer,
            ),
          ],
        ),
        
        const SizedBox(height: 40),
        
        // Sessions Progress
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(goal, (index) {
            final isDone = index < completed;
            return Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? _getModeColor('focus') : Colors.black.withValues(alpha: 0.05),
                border: isDone ? null : Border.all(color: Colors.black.withValues(alpha: 0.1)),
              ),
              child: isDone ? const Icon(Icons.check, size: 8, color: Colors.white) : null,
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          '$completed / $goal SESSIONS',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey[500], letterSpacing: 1),
        ),
      ],
    );
  }

  Widget _buildModeButton(BuildContext context, String label, String modeId, bool isSelected) {
    return GestureDetector(
      onTap: () => controller.setTimerMode(modeId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.black : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayButton(bool isRunning) {
    return GestureDetector(
      onTap: controller.toggleTimer,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Icon(
          isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildRoundButton({required IconData icon, required VoidCallback onPressed}) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: Colors.grey[600]),
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.05),
        padding: const EdgeInsets.all(12),
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final int mins = seconds ~/ 60;
    final int secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Color _getModeColor(String mode) {
    switch (mode) {
      case 'focus': return const Color(0xFFE11D48); // Rose 600
      case 'shortBreak': return const Color(0xFF10B981); // Emerald 500
      case 'longBreak': return const Color(0xFF3B82F6); // Blue 500
      default: return const Color(0xFFE11D48);
    }
  }
}
