import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musly/widgets/common/lazy_indexed_stack.dart';

void main() {
  testWidgets('switching lazily built tabs keeps semantics consistent',
      (tester) async {
    final semantics = tester.ensureSemantics();
    var index = 0;
    late StateSetter update;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return LazyIndexedStack(
              index: index,
              children: const [
                CustomScrollView(
                  slivers: [
                    SliverAppBar(title: Text('Home')),
                    SliverFillRemaining(child: Text('Home content')),
                  ],
                ),
                CustomScrollView(
                  slivers: [
                    SliverAppBar(title: Text('Library')),
                    SliverFillRemaining(child: Text('Library content')),
                  ],
                ),
                CustomScrollView(
                  slivers: [
                    SliverAppBar(title: Text('Search')),
                    SliverFillRemaining(child: Text('Search content')),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );

    for (var iteration = 1; iteration <= 10; iteration++) {
      final target = iteration % 3;
      update(() => index = target);
      // First frame activates a new tab offstage; the following frame exposes
      // it after its render and semantics subtrees have both been built.
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
    }

    semantics.dispose();
  });
}
