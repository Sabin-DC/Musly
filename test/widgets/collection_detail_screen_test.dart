import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musly/models/album.dart';
import 'package:musly/providers/library_provider.dart';
import 'package:musly/screens/media/collections_screen.dart';
import 'package:musly/services/album_collection_service.dart';
import 'package:musly/services/audio_handler.dart';
import 'package:musly/services/subsonic_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CollectionLibraryProvider extends LibraryProvider {
  final List<Album> testAlbums;

  _CollectionLibraryProvider(this.testAlbums)
      : super(SubsonicService(), MuslyAudioHandler());

  @override
  List<Album> get cachedAllAlbums => testAlbums;

  @override
  Future<void> ensureLibraryLoaded() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('collection detail has an index and no bottom add button',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final albums = List.generate(
      8,
      (index) => Album(
        id: 'album-$index',
        name: '${String.fromCharCode(65 + index)} Album',
        artist: 'Artist',
      ),
    )..insert(
        0,
        Album(
          id: 'numeric-album',
          name: '13 Sentinels',
          artist: 'Artist',
        ),
      );
    final collections = AlbumCollectionService();
    await collections.initialize();
    final collection = await collections.create(
      'VGM',
      albumIds: albums.map((album) => album.id),
    );
    final library = _CollectionLibraryProvider(albums);
    addTearDown(collections.dispose);
    addTearDown(library.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AlbumCollectionService>.value(
            value: collections,
          ),
          ChangeNotifierProvider<LibraryProvider>.value(value: library),
        ],
        child: MaterialApp(
          home: CollectionDetailScreen(collectionId: collection.id),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('H'), findsOneWidget);
    expect(find.text('#'), findsOneWidget);

    final hashCenter = tester.getCenter(find.text('#'));
    final aCenter = tester.getCenter(find.text('A'));
    expect(hashCenter.dy, lessThan(aCenter.dy));

    final indicator = find.byKey(
      const ValueKey('collection-fast-scroll-indicator'),
    );
    expect(tester.widget<AnimatedOpacity>(indicator).opacity, 0);

    final gesture = await tester.startGesture(tester.getCenter(find.text('D')));
    await tester.pump(const Duration(milliseconds: 180));
    expect(tester.widget<AnimatedOpacity>(indicator).opacity, 1);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('collection-fast-scroll-letter')),
          )
          .data,
      'D',
    );

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 180));
    expect(tester.widget<AnimatedOpacity>(indicator).opacity, 0);
  });
}
