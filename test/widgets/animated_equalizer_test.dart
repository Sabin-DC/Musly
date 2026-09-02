import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musly/widgets/common/animated_equalizer.dart';

void main() {
  testWidgets('shows a pause indicator when the current song is paused',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimatedEqualizer(color: Colors.red, isPlaying: false),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('paused-song-indicator')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Paused'), findsOneWidget);
  });

  testWidgets('shows animated bars while the current song is playing',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimatedEqualizer(color: Colors.red, isPlaying: true),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('paused-song-indicator')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AnimatedEqualizer),
        matching: find.byType(AnimatedBuilder),
      ),
      findsNWidgets(3),
    );
  });
}
