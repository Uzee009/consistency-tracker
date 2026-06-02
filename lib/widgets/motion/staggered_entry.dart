import 'package:flutter/material.dart';
import '../../theme/motion.dart';
import '../../utils/motion_accessibility.dart';

/// A widget that provides a staggered entry animation (opacity + translation).
/// Used for task tiles and other list items on initial appearance.
class StaggeredEntry extends StatefulWidget {
  final Widget child;
  final int index;
  final int staggerMs;
  final Duration? duration;

  const StaggeredEntry({
    super.key,
    required this.child,
    required this.index,
    this.staggerMs = 35,
    this.duration,
  });

  @override
  State<StaggeredEntry> createState() => _StaggeredEntryState();
}

class _StaggeredEntryState extends State<StaggeredEntry>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _translate;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration ?? Motion.medium,
    );

    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Motion.standardEase,
    );

    _translate = Tween<double>(begin: 8.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Motion.standardEase,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final accessibility = MotionAccessibility.of(context);
    _controller.duration = accessibility.apply(widget.duration ?? Motion.medium);
    _startAnimation(accessibility);
  }

  void _startAnimation(MotionAccessibility accessibility) async {
    if (_controller.isAnimating || _controller.isCompleted) return;
    
    final delay = (widget.index * widget.staggerMs).clamp(0, 350);
    await Future.delayed(accessibility.apply(Duration(milliseconds: delay)));
    if (mounted) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MotionAccessibility.of(context).reduce) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: Offset(0, _translate.value),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
