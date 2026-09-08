import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../utils/navigation_helper.dart';
import '../../utils/album_grid_layout.dart';
import '../../widgets/common/album_artwork.dart';
import '../detail/album_screen.dart';
import 'album_collection_screen.dart';

class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  bool _gridView = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<LibraryProvider>().ensureLibraryLoaded();
    });
  }

  Future<void> _createCollection() async {
    final details = await showCollectionEditor(context);
    if (details == null || !mounted) return;
    final collection = await context.read<AlbumCollectionService>().create(
          details.name,
          description: details.description,
        );
    if (mounted) {
      NavigationHelper.push(
        context,
        CollectionDetailScreen(collectionId: collection.id),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<AlbumCollectionService>();
    final library = context.watch<LibraryProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collections'),
        actions: [
          IconButton(
            tooltip: _gridView ? 'List view' : 'Grid view',
            onPressed: () => setState(() => _gridView = !_gridView),
            icon: Icon(_gridView
                ? CupertinoIcons.list_bullet
                : CupertinoIcons.square_grid_2x2),
          ),
          IconButton(
            tooltip: 'New collection',
            onPressed: _createCollection,
            icon: const Icon(CupertinoIcons.add),
          ),
        ],
      ),
      body: !service.initialized
          ? const Center(child: CircularProgressIndicator())
          : service.collections.isEmpty
              ? _EmptyCollections(onCreate: _createCollection)
              : _gridView
                  ? LayoutBuilder(
                      builder: (context, constraints) => GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: AlbumGridLayout.columns(
                            context,
                            constraints.maxWidth,
                          ),
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.72,
                        ),
                        itemCount: service.collections.length,
                        itemBuilder: (context, index) => _CollectionCard(
                          collection: service.collections[index],
                          albums: resolveCollectionAlbums(
                            service.collections[index],
                            library.cachedAllAlbums,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      itemCount: service.collections.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final collection = service.collections[index];
                        return _CollectionListTile(
                          collection: collection,
                          albums: resolveCollectionAlbums(
                            collection,
                            library.cachedAllAlbums,
                          ),
                        );
                      },
                    ),
      floatingActionButton: service.collections.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _createCollection,
              icon: const Icon(CupertinoIcons.add),
              label: const Text('New collection'),
            ),
    );
  }
}

class CollectionDetailScreen extends StatefulWidget {
  final String collectionId;

  const CollectionDetailScreen({super.key, required this.collectionId});

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  bool _gridView = true;
  bool _selecting = false;
  bool _isStartingShuffle = false;
  final Set<String> _selectedIds = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<LibraryProvider>().ensureLibraryLoaded();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _exitSelection() => setState(() {
        _selecting = false;
        _selectedIds.clear();
      });

  void _toggle(String albumId) => setState(() {
        if (!_selectedIds.add(albumId)) _selectedIds.remove(albumId);
      });

  Future<void> _removeSelected() async {
    await context
        .read<AlbumCollectionService>()
        .removeAlbums(widget.collectionId, _selectedIds);
    if (mounted) _exitSelection();
  }

  Future<void> _edit(AlbumCollection collection) async {
    final details = await showCollectionEditor(
      context,
      initialName: collection.name,
      initialDescription: collection.description,
    );
    if (details == null || !mounted) return;
    await context.read<AlbumCollectionService>().update(
          collection.id,
          name: details.name,
          description: details.description,
        );
  }

  Future<void> _delete(AlbumCollection collection) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete collection?'),
        content: Text(
          'Delete “${collection.name}”? The albums themselves will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<AlbumCollectionService>().delete(collection.id);
    if (mounted) Navigator.pop(context);
  }

  void _openAlbums() {
    NavigationHelper.push(
      context,
      const AlbumCollectionScreen.recent(startInSelectionMode: true),
    );
  }

  void _shufflePlayCollection(List<Album> albums) {
    if (albums.isEmpty || _isStartingShuffle) return;
    setState(() => _isStartingShuffle = true);
    context
        .read<PlayerProvider>()
        .startDynamicAlbumShuffle(albums)
        .catchError((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start collection shuffle')),
        );
      }
    });
    setState(() => _isStartingShuffle = false);
  }

  @override
  Widget build(BuildContext context) {
    final collection =
        context.watch<AlbumCollectionService>().byId(widget.collectionId);
    if (collection == null) {
      return const Scaffold(body: Center(child: Text('Collection not found')));
    }
    final albums = resolveCollectionAlbums(
      collection,
      context.watch<LibraryProvider>().cachedAllAlbums,
    )..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Scaffold(
      appBar: AppBar(
        leading: _selecting
            ? IconButton(
                onPressed: _exitSelection,
                icon: const Icon(CupertinoIcons.clear),
              )
            : null,
        title: Text(
            _selecting ? '${_selectedIds.length} selected' : collection.name),
        actions: _selecting
            ? [
                IconButton(
                  tooltip: 'Remove from collection',
                  onPressed: _selectedIds.isEmpty ? null : _removeSelected,
                  icon: const Icon(CupertinoIcons.trash),
                ),
              ]
            : [
                IconButton(
                  tooltip: 'Shuffle collection',
                  onPressed: albums.isEmpty || _isStartingShuffle
                      ? null
                      : () => _shufflePlayCollection(albums),
                  icon: _isStartingShuffle
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(CupertinoIcons.shuffle),
                ),
                IconButton(
                  tooltip: _gridView ? 'List view' : 'Grid view',
                  onPressed: () => setState(() => _gridView = !_gridView),
                  icon: Icon(_gridView
                      ? CupertinoIcons.list_bullet
                      : CupertinoIcons.square_grid_2x2),
                ),
                IconButton(
                  tooltip: 'Add albums',
                  onPressed: _openAlbums,
                  icon: const Icon(CupertinoIcons.add_circled),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') _edit(collection);
                    if (value == 'select') {
                      setState(() => _selecting = true);
                    }
                    if (value == 'delete') _delete(collection);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(
                        value: 'select', child: Text('Select albums')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
      ),
      body: albums.isEmpty
          ? _EmptyCollection(onAdd: _openAlbums)
          : Stack(
              children: [
                CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 32, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (collection.description != null) ...[
                              Text(collection.description!),
                              const SizedBox(height: 8),
                            ],
                            Text(
                              '${albums.length} ${albums.length == 1 ? 'album' : 'albums'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_gridView)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 32, 100),
                        sliver: SliverLayoutBuilder(
                          builder: (context, constraints) => SliverGrid.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: AlbumGridLayout.columns(
                                context,
                                constraints.crossAxisExtent,
                              ),
                              mainAxisSpacing: 18,
                              crossAxisSpacing: 14,
                              childAspectRatio: 0.72,
                            ),
                            itemCount: albums.length,
                            itemBuilder: (_, index) => _CollectionAlbumTile(
                              album: albums[index],
                              selecting: _selecting,
                              selected: _selectedIds.contains(albums[index].id),
                              onTap: () => _onAlbumTap(albums[index]),
                              onLongPress: () => _startSelection(albums[index]),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.only(right: 24, bottom: 80),
                        sliver: SliverList.builder(
                          itemCount: albums.length,
                          itemBuilder: (_, index) {
                            final album = albums[index];
                            return ListTile(
                              leading: Stack(
                                children: [
                                  AlbumArtwork(
                                    coverArt: album.coverArt,
                                    size: 56,
                                    borderRadius: 6,
                                  ),
                                  if (_selecting)
                                    _SelectionMark(
                                      selected: _selectedIds.contains(album.id),
                                    ),
                                ],
                              ),
                              title: Text(album.name),
                              subtitle: Text(album.artist ?? 'Unknown artist'),
                              onTap: () => _onAlbumTap(album),
                              onLongPress: () => _startSelection(album),
                            );
                          },
                        ),
                      ),
                  ],
                ),
                if (albums.length >= 8)
                  _CollectionAlphabetIndex(
                    albums: albums,
                    onLetterSelected: (letter) =>
                        _scrollToLetter(letter, albums),
                  ),
              ],
            ),
    );
  }

  void _scrollToLetter(String letter, List<Album> albums) {
    final targetIndex = albums.indexWhere((album) {
      final name = album.name.trim();
      if (name.isEmpty) return letter == '#';
      final first = name[0].toUpperCase();
      return letter == '#'
          ? !RegExp(r'[A-Z]').hasMatch(first)
          : first == letter;
    });
    if (targetIndex < 0 || !_scrollController.hasClients) return;
    final fraction =
        albums.length <= 1 ? 0.0 : targetIndex / (albums.length - 1);
    final offset = fraction * _scrollController.position.maxScrollExtent;
    _scrollController.jumpTo(offset);
  }

  void _onAlbumTap(Album album) {
    if (_selecting) {
      _toggle(album.id);
    } else {
      NavigationHelper.push(context, AlbumScreen(albumId: album.id));
    }
  }

  void _startSelection(Album album) {
    setState(() {
      _selecting = true;
      _selectedIds.add(album.id);
    });
  }
}

Future<String?> showAddAlbumsToCollectionSheet(
  BuildContext context,
  Iterable<String> albumIds,
) async {
  final ids = albumIds.toSet();
  if (ids.isEmpty) return null;
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _AddToCollectionSheet(albumIds: ids),
  );
}

class _AddToCollectionSheet extends StatelessWidget {
  final Set<String> albumIds;

  const _AddToCollectionSheet({required this.albumIds});

  Future<void> _create(BuildContext context) async {
    final details = await showCollectionEditor(context);
    if (details == null || !context.mounted) return;
    final collection = await context.read<AlbumCollectionService>().create(
          details.name,
          description: details.description,
          albumIds: albumIds,
        );
    if (context.mounted) Navigator.pop(context, collection.id);
  }

  @override
  Widget build(BuildContext context) {
    final collections = context.watch<AlbumCollectionService>().collections;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Add to collection',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              subtitle: Text(
                  '${albumIds.length} ${albumIds.length == 1 ? 'album' : 'albums'} selected'),
            ),
            ListTile(
              leading: const CircleAvatar(child: Icon(CupertinoIcons.add)),
              title: const Text('New collection'),
              onTap: () => _create(context),
            ),
            if (collections.isNotEmpty) const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: collections.length,
                itemBuilder: (_, index) {
                  final collection = collections[index];
                  return ListTile(
                    leading: const Icon(CupertinoIcons.square_stack_3d_up),
                    title: Text(collection.name),
                    subtitle: Text(
                        '${collection.albumIds.length} ${collection.albumIds.length == 1 ? 'album' : 'albums'}'),
                    onTap: () async {
                      await context
                          .read<AlbumCollectionService>()
                          .addAlbums(collection.id, albumIds);
                      if (context.mounted) {
                        Navigator.pop(context, collection.id);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CollectionEditorResult {
  final String name;
  final String? description;

  const CollectionEditorResult(this.name, this.description);
}

Future<CollectionEditorResult?> showCollectionEditor(
  BuildContext context, {
  String? initialName,
  String? initialDescription,
}) {
  return showDialog<CollectionEditorResult>(
    context: context,
    builder: (_) => _CollectionEditorDialog(
      initialName: initialName,
      initialDescription: initialDescription,
    ),
  );
}

class _CollectionEditorDialog extends StatefulWidget {
  final String? initialName;
  final String? initialDescription;

  const _CollectionEditorDialog({this.initialName, this.initialDescription});

  @override
  State<_CollectionEditorDialog> createState() =>
      _CollectionEditorDialogState();
}

class _CollectionEditorDialogState extends State<_CollectionEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
    _description = TextEditingController(text: widget.initialDescription);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final description = _description.text.trim();
    Navigator.pop(
      context,
      CollectionEditorResult(name, description.isEmpty ? null : description),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initialName != null;
    return AlertDialog(
      title: Text(editing ? 'Edit collection' : 'New collection'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Optional',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _name,
          builder: (_, value, __) => FilledButton(
            onPressed: value.text.trim().isEmpty ? null : _submit,
            child: Text(editing ? 'Save' : 'Create'),
          ),
        ),
      ],
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final AlbumCollection collection;
  final List<Album> albums;

  const _CollectionCard({required this.collection, required this.albums});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => NavigationHelper.push(
        context,
        CollectionDetailScreen(collectionId: collection.id),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: CollectionArtwork(albums: albums),
          ),
          const SizedBox(height: 8),
          Text(collection.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(
            '${collection.albumIds.length} ${collection.albumIds.length == 1 ? 'album' : 'albums'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _CollectionListTile extends StatelessWidget {
  final AlbumCollection collection;
  final List<Album> albums;

  const _CollectionListTile({required this.collection, required this.albums});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: SizedBox.square(
        dimension: 72,
        child: CollectionArtwork(albums: albums),
      ),
      title: Text(collection.name),
      subtitle: Text(
          '${collection.albumIds.length} ${collection.albumIds.length == 1 ? 'album' : 'albums'}'),
      trailing: const Icon(CupertinoIcons.chevron_forward, size: 18),
      onTap: () => NavigationHelper.push(
        context,
        CollectionDetailScreen(collectionId: collection.id),
      ),
    );
  }
}

class CollectionArtwork extends StatelessWidget {
  final List<Album> albums;

  const CollectionArtwork({super.key, required this.albums});

  @override
  Widget build(BuildContext context) {
    final covers = albums.take(4).toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ColoredBox(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: covers.isEmpty
            ? Center(
                child: Icon(
                  CupertinoIcons.square_stack_3d_up_fill,
                  size: 54,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              )
            : _coverLayout(covers),
      ),
    );
  }

  Widget _cover(Album album) => SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: AlbumArtwork(
            coverArt: album.coverArt,
            size: 240,
            borderRadius: 0,
          ),
        ),
      );

  Widget _coverLayout(List<Album> covers) {
    if (covers.length == 1) return _cover(covers.first);
    if (covers.length == 2) {
      return Row(
        children:
            covers.map((album) => Expanded(child: _cover(album))).toList(),
      );
    }
    if (covers.length == 3) {
      return Row(
        children: [
          Expanded(child: _cover(covers[0])),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _cover(covers[1])),
                Expanded(child: _cover(covers[2])),
              ],
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _cover(covers[0])),
              Expanded(child: _cover(covers[1])),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _cover(covers[2])),
              Expanded(child: _cover(covers[3])),
            ],
          ),
        ),
      ],
    );
  }
}

class _CollectionAlphabetIndex extends StatefulWidget {
  final List<Album> albums;
  final ValueChanged<String> onLetterSelected;

  const _CollectionAlphabetIndex({
    required this.albums,
    required this.onLetterSelected,
  });

  @override
  State<_CollectionAlphabetIndex> createState() =>
      _CollectionAlphabetIndexState();
}

class _CollectionAlphabetIndexState extends State<_CollectionAlphabetIndex> {
  String? _activeLetter;
  int? _activeIndex;
  bool _interacting = false;

  List<String> get _letters {
    final available = widget.albums.map((album) {
      final name = album.name.trim();
      if (name.isEmpty) return '#';
      final first = name[0].toUpperCase();
      return RegExp(r'[A-Z]').hasMatch(first) ? first : '#';
    }).toSet();
    final letters = <String>[
      if (available.contains('#')) '#',
      ...List.generate(26, (i) => String.fromCharCode(65 + i))
          .where(available.contains),
    ];
    return letters;
  }

  void _selectAt(double y, double height, List<String> letters) {
    if (letters.isEmpty || height <= 0) return;
    final candidateIndex =
        ((y / height) * letters.length).floor().clamp(0, letters.length - 1);
    final rowHeight = height / letters.length;
    var index = candidateIndex;

    // Keep the current letter until the finger is a little way into its
    // neighbour. This prevents an incidental movement while lifting a finger
    // from selecting the adjacent letter.
    if (_activeIndex != null && (candidateIndex - _activeIndex!).abs() == 1) {
      const boundaryInset = 0.28;
      if (candidateIndex > _activeIndex! &&
          y < ((_activeIndex! + 1 + boundaryInset) * rowHeight)) {
        index = _activeIndex!;
      } else if (candidateIndex < _activeIndex! &&
          y > ((_activeIndex! - boundaryInset) * rowHeight)) {
        index = _activeIndex!;
      }
    }

    final letter = letters[index];
    if (!_interacting || _activeLetter != letter) {
      setState(() {
        _interacting = true;
        _activeLetter = letter;
        _activeIndex = index;
      });
      HapticFeedback.lightImpact();
      widget.onLetterSelected(letter);
    }
  }

  void _endInteraction() {
    if (_interacting) {
      setState(() {
        _interacting = false;
        _activeIndex = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final letters = _letters;
    if (letters.isEmpty) return const SizedBox.shrink();
    final indexHeight =
        (MediaQuery.sizeOf(context).height / 3).clamp(150.0, 260.0);
    return Positioned.fill(
      child: Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: 112,
          height: indexHeight,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerRight,
            children: [
              IgnorePointer(
                child: AnimatedOpacity(
                  key: const ValueKey('collection-fast-scroll-indicator'),
                  opacity: _interacting ? 1 : 0,
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  child: AnimatedSlide(
                    offset: _interacting ? Offset.zero : const Offset(0.45, 0),
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutCubic,
                    child: Container(
                      width: 54,
                      height: 54,
                      margin: const EdgeInsets.only(right: 32),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _activeLetter ?? '',
                        key: const ValueKey('collection-fast-scroll-letter'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: LayoutBuilder(
                  builder: (context, constraints) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) => _selectAt(
                      details.localPosition.dy,
                      constraints.maxHeight,
                      letters,
                    ),
                    onTapUp: (_) => _endInteraction(),
                    onTapCancel: _endInteraction,
                    onVerticalDragStart: (details) => _selectAt(
                      details.localPosition.dy,
                      constraints.maxHeight,
                      letters,
                    ),
                    onVerticalDragUpdate: (details) => _selectAt(
                      details.localPosition.dy,
                      constraints.maxHeight,
                      letters,
                    ),
                    onVerticalDragEnd: (_) => _endInteraction(),
                    onVerticalDragCancel: _endInteraction,
                    child: SizedBox(
                      // The visual index remains narrow, but a larger target
                      // makes it easier to scrub without losing the index.
                      width: 44,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: 24,
                          child: Column(
                            children: letters
                                .map(
                                  (letter) => Expanded(
                                    child: Center(
                                      child: Text(
                                        letter,
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionAlbumTile extends StatelessWidget {
  final Album album;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _CollectionAlbumTile({
    required this.album,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AlbumArtwork(
                  coverArt: album.coverArt,
                  size: 220,
                  borderRadius: 8,
                ),
                if (selecting) _SelectionMark(selected: selected),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(album.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(album.artist ?? 'Unknown artist',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SelectionMark extends StatelessWidget {
  final bool selected;

  const _SelectionMark({required this.selected});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? Colors.black38 : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: selected
            ? Border.all(color: Theme.of(context).colorScheme.primary, width: 3)
            : null,
      ),
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            selected
                ? CupertinoIcons.checkmark_circle_fill
                : CupertinoIcons.circle,
            color:
                selected ? Theme.of(context).colorScheme.primary : Colors.white,
            size: 26,
            shadows: const [Shadow(blurRadius: 5)],
          ),
        ),
      ),
    );
  }
}

class _EmptyCollections extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyCollections({required this.onCreate});

  @override
  Widget build(BuildContext context) => _EmptyState(
        icon: CupertinoIcons.square_stack_3d_up,
        title: 'No collections yet',
        message: 'Group albums by genre, mood, era, or anything you like.',
        button: 'New collection',
        onPressed: onCreate,
      );
}

class _EmptyCollection extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyCollection({required this.onAdd});

  @override
  Widget build(BuildContext context) => _EmptyState(
        icon: CupertinoIcons.music_albums,
        title: 'No albums yet',
        message: 'Choose albums from your library to build this collection.',
        button: 'Choose albums',
        onPressed: onAdd,
      );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String button;
  final VoidCallback onPressed;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.button,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(CupertinoIcons.add),
              label: Text(button),
            ),
          ],
        ),
      ),
    );
  }
}

List<Album> resolveCollectionAlbums(
  AlbumCollection collection,
  Iterable<Album> libraryAlbums,
) {
  final byId = {for (final album in libraryAlbums) album.id: album};
  return collection.albumIds.map((id) => byId[id]).whereType<Album>().toList();
}
