import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/cupertino.dart';
import 'package:musly/screens/main/library_screen.dart';
import 'package:musly/services/album_collection_service.dart';

import '../bootstrap.dart';
import '../test_helpers.dart';

void main() {
  initializeTestEnvironment();

  testWidgets('Collections filter shows collections directly', (tester) async {
    final collections = AlbumCollectionService();
    await collections.initialize();
    await collections.create('Video Game Music', albumIds: ['album-1']);

    await tester.pumpWidget(
      createTestApp(
        child: const LibraryScreen(),
        albumCollectionService: collections,
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Collections'));
    await tester.pump();

    expect(find.text('Video Game Music'), findsOneWidget);
    expect(find.text('1 album'), findsOneWidget);
  });

  testWidgets('library add menu has a visible Material surface',
      (tester) async {
    await tester.pumpWidget(createTestApp(child: const LibraryScreen()));
    await tester.pump();

    await tester.tap(find.byIcon(CupertinoIcons.plus));
    await tester.pumpAndSettle();

    expect(find.text('Create collection'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
