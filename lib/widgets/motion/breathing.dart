import 'package:flutter/material.dart';
import '../../theme/motion.dart';
import '../../utils/motion_accessibility.dart';

/// Sine-wave opacity loop. See CURRENT_MODULE.md Step 17 for scope.
class Breathing extends StatefulWidget {
  final Widget child;
  final double minOpacity;
  final double maxOpacity;
  final Duration? period;
  final bool active;

  const Breathing({
    super.key,
    required this.child,
    this.minOpacity = 0.6,
    this.maxOpacity = 1.0,
    this.period,
    this.active = true,
  });

  @override
  State<Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<Breathing>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: widget.period ?? Motion.ambientBreath,
    );
    _animation = Tween<double>(begin: widget.minOpacity, end: widget.maxOpacity)
        .animate(CurvedAnimation(parent: _controller, curve: Motion.ambient));

    // We can't use context here, so we defer to after first frame or didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAnimationState();
  }

  @override
  void didUpdateWidget(Breathing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active || widget.period != oldWidget.period) {
      _controller.duration = widget.period ?? Motion.ambientBreath;
      _updateAnimationState();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateAnimationState();
    } else {
      _controller.stop();
    }
  }

  void _updateAnimationState() {
    if (!mounted) return;
    final accessibility = MotionAccessibility.of(context);
    if (widget.active &&
        !accessibility.reduce &&
        !accessibility.performanceMode) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accessibility = MotionAccessibility.of(context);
    if (!widget.active ||
        accessibility.reduce ||
        accessibility.performanceMode) {
      return Opacity(opacity: widget.maxOpacity, child: widget.child);
    }

    return FadeTransition(
      opacity: _animation,
      child: widget.child,
    );
  }
}
