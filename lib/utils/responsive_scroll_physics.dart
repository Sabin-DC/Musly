import 'package:flutter/material.dart';

/// iOS-style bouncing physics without the extra movement threshold Flutter
/// normally applies when a drag changes direction or resumes after stopping.
class ResponsiveBouncingScrollPhysics extends BouncingScrollPhysics {
  const ResponsiveBouncingScrollPhysics({super.parent});

  @override
  ResponsiveBouncingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ResponsiveBouncingScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double get dragStartDistanceMotionThreshold => 0;
}
