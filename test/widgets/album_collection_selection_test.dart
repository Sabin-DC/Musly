import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musly/models/album.dart';
import 'package:musly/screens/media/album_collection_screen.dart';
import 'package:musly/services/album_collection_service.dart';
import 'package:musly/widgets/cards/album_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(List<Album> albums, AlbumCollectionService collections) {
  return ChangeNotifierProvider.value(
    value: collections,
    child: MaterialApp(
      home: AlbumCollectionScreen(
        type: AlbumCollectionType.custom,
        customTitle: 'Albums',
        initialAlbums: albums,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AlbumCollectionService collections;
  late List<Album> albums;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    collections = AlbumCollectionService();
    await collections.initialize();
    albums = [
      Album(id: 'rock', name: 'Rock Album', artist: 'Artist', genre: 'Rock'),
      Album(id: 'jazz', name: 'Jazz Album', artist: 'Artist', genre: 'Jazz'),
    ];
  });

  testWidgets('selection controls are hidden until an album is long pressed',
      (tester) async {
    await tester.pumpWidget(_app(albums, collections));
    await tester.pump();

    expect(find.byIcon(CupertinoIcons.checkmark_alt_circle), findsNothing);
    await tester.longPress(find.text('Rock Album'));
    await tester.pump();

    expect(find.text('1 selected'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.checkmark_alt_circle), findsOneWidget);
  });

  testWidgets('a two-pointer gesture starts selection', (tester) async {
    await tester.pumpWidget(_app(albums, collections));
    await tester.pump();
    final cards = find.byType(AlbumCard);
    final first = tester.getCenter(cards.at(0));
    final second = tester.getCenter(cards.at(1));

    final firstGesture = await tester.startGesture(first, pointer: 1);
    final secondGesture = await tester.startGesture(second, pointer: 2);
    await tester.pump();

    expect(find.text('2 selected'), findsOneWidget);
    await firstGesture.up();
    await secondGesture.up();
  });

  testWidgets('genre filter limits the album grid', (tester) async {
    await tester.pumpWidget(_app(albums, collections));
    await tester.pump();

    await tester.tap(find.byIcon(CupertinoIcons.slider_horizontal_3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rock'));
    await tester.pumpAndSettle();

    expect(find.text('Rock Album'), findsOneWidget);
    expect(find.text('Jazz Album'), findsNothing);
  });

  testWidgets('selected albums can be added to an existing collection',
      (tester) async {
    final collection = await collections.create('Road trips');
    await tester.pumpWidget(_app(albums, collections));
    await tester.pump();

    await tester.longPress(find.text('Rock Album'));
    await tester.pump();
    await tester.tap(find.byTooltip('Add to collection'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Road trips'));
    await tester.pumpAndSettle();

    expect(collections.byId(collection.id)?.albumIds, ['rock']);
    expect(find.text('Added to Road trips'), findsOneWidget);
  });

  testWidgets('closing preactivated selection returns to the collection route',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => AlbumCollectionScreen(
                    type: AlbumCollectionType.custom,
                    customTitle: 'Choose albums',
                    initialAlbums: albums,
                    startInSelectionMode: true,
                  ),
                ),
              ),
              child: const Text('Collection detail'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Collection detail'));
    await tester.pumpAndSettle();
    expect(find.text('0 selected'), findsOneWidget);

    await tester.tap(find.byTooltip('Back to collection'));
    await tester.pumpAndSettle();

    expect(find.text('Collection detail'), findsOneWidget);
    expect(find.text('0 selected'), findsNothing);
  });
}
