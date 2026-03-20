// lib/widgets/pressable.dart
//
// Wraps any widget in a press animation: subtle scale down + opacity on tap.
// Use this everywhere instead of bare GestureDetector for a premium feel.
//
// Usage:
//   Pressable(
//     onTap: () => ...,
//     child: MyCard(),
//   )

import 'package:flutter/material.dart';
import '../theme/utils/haptics.dart';

class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final HapticStyle haptic;
  final double scaleDown;
  final Duration duration;
  final bool disabled;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.haptic = HapticStyle.light,
    this.scaleDown = 0.96,
    this.duration = const Duration(milliseconds: 100),
    this.disabled = false,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _scale = Tween<double>(begin: 1.0, end: widget.scaleDown)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween<double>(begin: 1.0, end: 0.75)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onTapDown(_) async {
    if (widget.disabled || widget.onTap == null) return;
    await _ctrl.forward();
  }

  Future<void> _onTapUp(_) async {
    await _ctrl.reverse();
    if (widget.onTap != null) {
      _fireHaptic();
      widget.onTap!();
    }
  }

  Future<void> _onTapCancel() => _ctrl.reverse();

  void _fireHaptic() {
    switch (widget.haptic) {
      case HapticStyle.none:   break;
      case HapticStyle.light:  AppHaptics.light();
      case HapticStyle.medium: AppHaptics.medium();
      case HapticStyle.heavy:  AppHaptics.heavy();
      case HapticStyle.select: AppHaptics.select();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onLongPress: widget.onLongPress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Opacity(
          opacity: _opacity.value,
          child: Transform.scale(scale: _scale.value, child: child),
        ),
        child: widget.child,
      ),
    );
  }
}

enum HapticStyle { none, light, medium, heavy, select }