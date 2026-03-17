import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:consistency_tracker_v1/controllers/dashboard_controller.dart';

class PomodoroTimer extends StatefulWidget {
  final DashboardController controller;
  const PomodoroTimer({super.key, required this.controller});

  @override
  State<PomodoroTimer> createState() => _PomodoroTimerState();
}

enum TimerMode { focus, shortBreak, longBreak }

class _PomodoroTimerState extends State<PomodoroTimer> {
  final Map<TimerMode, int> _durations = {
    TimerMode.focus: 25 * 60,
    TimerMode.shortBreak: 5 * 60,
    TimerMode.longBreak: 15 * 60,
  };

  TimerMode _currentMode = TimerMode.focus;
  late int _secondsRemaining;
  bool _isRunning = false;
  bool _isHovering = false;
  late int _sessionGoal;
  late int _sessionsCompleted;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = _durations[TimerMode.focus]!;
    _sessionsCompleted = widget.controller.todayRecord.pomodoroSessionsCompleted;
    _sessionGoal = widget.controller.todayRecord.pomodoroGoal;
  }

  @override
  void didUpdateWidget(covariant PomodoroTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the date changed or someone updated the stats elsewhere, sync back
    if (widget.controller.todayRecord.pomodoroSessionsCompleted != _sessionsCompleted) {
      setState(() => _sessionsCompleted = widget.controller.todayRecord.pomodoroSessionsCompleted);
    }
    if (widget.controller.todayRecord.pomodoroGoal != _sessionGoal) {
      setState(() => _sessionGoal = widget.controller.todayRecord.pomodoroGoal);
    }
  }

  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            _timer?.cancel();
            _isRunning = false;
            if (_currentMode == TimerMode.focus) {
              _sessionsCompleted++;
              if (_sessionsCompleted > _sessionGoal) _sessionsCompleted = _sessionGoal;
              // V8: Persist to DB
              widget.controller.updatePomodoroStats(_sessionsCompleted, _sessionGoal);
            }
          }
        });
      });
    }
    setState(() => _isRunning = !_isRunning);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _secondsRemaining = _durations[_currentMode]!;
    });
  }

  void _setMode(TimerMode mode) {
    _timer?.cancel();
    setState(() {
      _currentMode = mode;
      _isRunning = false;
      _secondsRemaining = _durations[mode]!;
    });
  }

  void _showSettingsDialog() {
    final focusController = TextEditingController(text: (_durations[TimerMode.focus]! ~/ 60).toString());
    final shortController = TextEditingController(text: (_durations[TimerMode.shortBreak]! ~/ 60).toString());
    final longController = TextEditingController(text: (_durations[TimerMode.longBreak]! ~/ 60).toString());
    final goalController = TextEditingController(text: _sessionGoal.toString());

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
              setState(() {
                _durations[TimerMode.focus] = (int.tryParse(focusController.text) ?? 25) * 60;
                _durations[TimerMode.shortBreak] = (int.tryParse(shortController.text) ?? 5) * 60;
                _durations[TimerMode.longBreak] = (int.tryParse(longController.text) ?? 15) * 60;
                _sessionGoal = int.tryParse(goalController.text) ?? 4;
                // V8: Persist goal to DB
                widget.controller.updatePomodoroStats(_sessionsCompleted, _sessionGoal);
                _resetTimer();
              });
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
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Color _getAccentColor(BuildContext context) {
    switch (_currentMode) {
      case TimerMode.focus: return Theme.of(context).colorScheme.primary;
      case TimerMode.shortBreak: return const Color(0xFF10B981);
      case TimerMode.longBreak: return Colors.blue[400]!;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _getAccentColor(context);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          // 1. MODE SELECTORS (Pinned Top Left)
          Positioned(
            top: 0,
            left: 0,
            child: Row(
              children: [
                _buildModeButton('Focus', TimerMode.focus),
                const SizedBox(width: 4),
                _buildModeButton('Short', TimerMode.shortBreak),
                const SizedBox(width: 4),
                _buildModeButton('Long', TimerMode.longBreak),
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
                  icon: Icons.refresh_rounded,
                  onPressed: _resetTimer,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 4),
                _buildHeaderControl(
                  icon: Icons.settings_outlined,
                  onPressed: _showSettingsDialog,
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
                const SizedBox(height: 24), // Offset for the pinned controls
                MouseRegion(
                  onEnter: (_) => setState(() => _isHovering = true),
                  onExit: (_) => setState(() => _isHovering = false),
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _toggleTimer,
                    behavior: HitTestBehavior.opaque,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity: _isHovering ? 0.2 : 1.0,
                          child: Text(
                            _formatTime(_secondsRemaining),
                            style: TextStyle(
                              fontSize: 84,
                              fontWeight: FontWeight.w400,
                              letterSpacing: -2,
                              color: _isRunning ? accentColor : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (_isHovering)
                          Icon(
                            _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 64,
                            color: accentColor.withValues(alpha: 0.8),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Session Progress Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_sessionGoal, (index) {
                    final isDone = index < _sessionsCompleted;
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

  Widget _buildModeButton(String label, TimerMode mode) {
    final isSelected = _currentMode == mode;
    final accentColor = _getAccentColor(context);
    return GestureDetector(
      onTap: () => _setMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
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

  Widget _buildHeaderControl({required IconData icon, required VoidCallback onPressed, required Color color}) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Padding(padding: const EdgeInsets.all(4.0), child: Icon(icon, size: 16, color: color)),
      ),
    );
  }
}
