import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musly/widgets/common/shimmer_loading.dart';

void main() {
  testWidgets('infinite shimmer size fills a finite grid cell', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 0.78,
            children: const [
              AlbumCardShimmer(size: double.infinity),
              AlbumCardShimmer(size: double.infinity),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(AlbumCardShimmer), findsNWidgets(2));
  });
}
