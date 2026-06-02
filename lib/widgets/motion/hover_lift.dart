import 'package:flutter/material.dart';
import '../../theme/motion.dart';
import '../../utils/motion_accessibility.dart';

/// Lift on hover with shadow. See CURRENT_MODULE.md Step 17 for scope.
class HoverLift extends StatefulWidget {
  final Widget child;
  final double liftPx;
  final double restElevation;
  final double hoverElevation;
  final Duration? duration;

  const HoverLift({
    super.key,
    required this.child,
    this.liftPx = 3,
    this.restElevation = 0,
    this.hoverElevation = 8,
    this.duration,
  });

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final accessibility = MotionAccessibility.of(context);
    if (accessibility.reduce) return widget.child;

    final effectiveDuration = accessibility.apply(widget.duration ?? Motion.fast);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: effectiveDuration,
        curve: Motion.standardEase,
        transform: Matrix4.translationValues(0, _isHovered ? -widget.liftPx : 0, 0),
        child: AnimatedPhysicalModel(
          duration: effectiveDuration,
          curve: Motion.standardEase,
          shape: BoxShape.rectangle,
          elevation: _isHovered ? widget.hoverElevation : widget.restElevation,
          color: Colors.transparent,
          shadowColor: Colors.black,
          child: widget.child,
        ),
      ),
    );
  }
}
