import 'package:flutter/material.dart';

/// Scroll physics that clamps overscroll at the top but allows limited bounce at the bottom.
class BottomBouncingScrollPhysics extends ClampingScrollPhysics {
  const BottomBouncingScrollPhysics({ScrollPhysics? parent}) : super(parent: parent);

  @override
  ClampingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return BottomBouncingScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final double boundary = super.applyBoundaryConditions(position, value);
    // Allow limited overscroll at the bottom (max 30 pixels), clamp at the top
    if (boundary > 0) return boundary.clamp(0, 30.0);
    return boundary;
  }
}