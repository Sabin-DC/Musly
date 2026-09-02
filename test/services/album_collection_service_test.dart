import 'package:flutter_test/flutter_test.dart';
import 'package:musly/services/album_collection_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('creates a collection and adds albums without duplicates', () async {
    final service = AlbumCollectionService();
    await service.initialize();
    final collection = await service.create('Favorites', albumIds: ['a']);

    final added = await service.addAlbums(collection.id, ['a', 'b', 'b']);

    expect(added, 1);
    expect(service.byId(collection.id)?.albumIds, ['a', 'b']);
  });

  test('persists collection edits and removals', () async {
    final service = AlbumCollectionService();
    await service.initialize();
    final collection = await service.create(
      'Original',
      description: 'Old description',
      albumIds: ['a', 'b'],
    );
    await service.update(collection.id, name: 'Renamed', description: '');
    await service.removeAlbums(collection.id, ['a']);

    final restored = AlbumCollectionService();
    await restored.initialize();

    expect(restored.byId(collection.id)?.name, 'Renamed');
    expect(restored.byId(collection.id)?.description, isNull);
    expect(restored.byId(collection.id)?.albumIds, ['b']);
  });
}
