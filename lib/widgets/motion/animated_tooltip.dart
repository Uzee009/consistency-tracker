import 'package:flutter/material.dart';
import '../../utils/motion_accessibility.dart';

class AnimatedTooltip extends StatefulWidget {
  final String message;
  final Widget child;
  final Duration showDelay;
  final bool preferBelow;

  const AnimatedTooltip({
    super.key,
    required this.message,
    required this.child,
    this.showDelay = const Duration(milliseconds: 500),
    this.preferBelow = true,
  });

  @override
  State<AnimatedTooltip> createState() => _AnimatedTooltipState();
}

class _AnimatedTooltipState extends State<AnimatedTooltip> {
  @override
  Widget build(BuildContext context) {
    final motion = MotionAccessibility.of(context);
    final delay = motion.reduce ? const Duration(milliseconds: 200) : widget.showDelay;

    return Tooltip(
      message: widget.message,
      waitDuration: delay,
      verticalOffset: 12,
      preferBelow: widget.preferBelow,
      showDuration: const Duration(milliseconds: 4000),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: TextStyle(
        color: Theme.of(context).colorScheme.onInverseSurface,
        fontSize: 12,
      ),
      enableTapToDismiss: true,
      child: MouseRegion(
        child: widget.child,
      ),
    );
  }
}
