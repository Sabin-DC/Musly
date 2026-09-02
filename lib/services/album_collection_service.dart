import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/album_collection.dart';

class AlbumCollectionService extends ChangeNotifier {
  static const _storageKey = 'album_collections_v2';
  static const _uuid = Uuid();

  final List<AlbumCollection> _collections = [];
  bool _initialized = false;

  List<AlbumCollection> get collections => List.unmodifiable(_collections);
  bool get initialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    final raw = (await SharedPreferences.getInstance()).getString(_storageKey);
    if (raw != null) {
      try {
        final values = jsonDecode(raw) as List<dynamic>;
        _collections.addAll(values.map((value) =>
            AlbumCollection.fromJson(Map<String, dynamic>.from(value as Map))));
      } catch (error) {
        debugPrint('Could not load album collections: $error');
      }
    }
    _sort();
    _initialized = true;
    notifyListeners();
  }

  AlbumCollection? byId(String id) {
    for (final collection in _collections) {
      if (collection.id == id) return collection;
    }
    return null;
  }

  Future<AlbumCollection> create(
    String name, {
    String? description,
    Iterable<String> albumIds = const [],
  }) async {
    final now = DateTime.now();
    final collection = AlbumCollection(
      id: _uuid.v4(),
      name: name.trim(),
      description: _clean(description),
      albumIds: albumIds.toSet().toList(),
      createdAt: now,
      updatedAt: now,
    );
    _collections.insert(0, collection);
    await _persist();
    return collection;
  }

  Future<int> addAlbums(String collectionId, Iterable<String> albumIds) async {
    final index = _collections.indexWhere((item) => item.id == collectionId);
    if (index == -1) return 0;
    final ids = _collections[index].albumIds.toSet();
    final originalCount = ids.length;
    ids.addAll(albumIds);
    final added = ids.length - originalCount;
    if (added == 0) return 0;
    _collections[index] = _collections[index].copyWith(
      albumIds: ids.toList(),
      updatedAt: DateTime.now(),
    );
    await _persist();
    return added;
  }

  Future<void> removeAlbums(
      String collectionId, Iterable<String> albumIds) async {
    final index = _collections.indexWhere((item) => item.id == collectionId);
    if (index == -1) return;
    final removed = albumIds.toSet();
    _collections[index] = _collections[index].copyWith(
      albumIds: _collections[index]
          .albumIds
          .where((id) => !removed.contains(id))
          .toList(),
      updatedAt: DateTime.now(),
    );
    await _persist();
  }

  Future<void> update(
    String collectionId, {
    required String name,
    String? description,
  }) async {
    final index = _collections.indexWhere((item) => item.id == collectionId);
    if (index == -1) return;
    final cleaned = _clean(description);
    _collections[index] = _collections[index].copyWith(
      name: name.trim(),
      description: cleaned,
      clearDescription: cleaned == null,
      updatedAt: DateTime.now(),
    );
    await _persist();
  }

  Future<void> delete(String collectionId) async {
    _collections.removeWhere((item) => item.id == collectionId);
    await _persist();
  }

  String? _clean(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }

  void _sort() =>
      _collections.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  Future<void> _persist() async {
    _sort();
    await (await SharedPreferences.getInstance()).setString(
      _storageKey,
      jsonEncode(_collections.map((item) => item.toJson()).toList()),
    );
    notifyListeners();
  }
}
