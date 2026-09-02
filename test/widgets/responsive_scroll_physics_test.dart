import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musly/utils/responsive_scroll_physics.dart';

void main() {
  test('responsive physics removes the drag restart threshold', () {
    const physics = ResponsiveBouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );

    expect(physics.dragStartDistanceMotionThreshold, 0);
    expect(physics.shouldAcceptUserOffset(_ScrollableMetrics()), isTrue);
  });
}

class _ScrollableMetrics extends FixedScrollMetrics {
  _ScrollableMetrics()
      : super(
          minScrollExtent: 0,
          maxScrollExtent: 100,
          pixels: 0,
          viewportDimension: 50,
          axisDirection: AxisDirection.down,
          devicePixelRatio: 1,
        );
}
