import 'package:flutter/material.dart';
import '../../theme/motion.dart';
import '../../utils/motion_accessibility.dart';

/// Reveal opacity on hover. See CURRENT_MODULE.md Step 17 for scope.
class RevealOnHover extends StatefulWidget {
  final Widget child;
  final double restOpacity;
  final double hoverOpacity;
  final Duration? duration;

  const RevealOnHover({
    super.key,
    required this.child,
    this.restOpacity = 0.0,
    this.hoverOpacity = 0.8,
    this.duration,
  });

  @override
  State<RevealOnHover> createState() => _RevealOnHoverState();
}

class _RevealOnHoverState extends State<RevealOnHover> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final accessibility = MotionAccessibility.of(context);
    if (accessibility.reduce) {
      return Opacity(opacity: widget.hoverOpacity, child: widget.child);
    }

    final effectiveDuration = accessibility.apply(widget.duration ?? Motion.fast);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedOpacity(
        opacity: _isHovered ? widget.hoverOpacity : widget.restOpacity,
        duration: effectiveDuration,
        curve: Motion.standardEase,
        child: widget.child,
      ),
    );
  }
}
