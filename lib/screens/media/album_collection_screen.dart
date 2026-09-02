import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/album.dart';
import '../../providers/library_provider.dart';
import '../../services/album_collection_service.dart';
import '../../services/subsonic_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/screen_helper.dart';
import '../../utils/album_grid_layout.dart';
import '../../utils/responsive_scroll_physics.dart';
import '../../widgets/widgets.dart';
import '../detail/album_screen.dart';
import 'collections_screen.dart';

enum AlbumCollectionType {
  recent,
  newest,
  topRated,
  starred,
  custom,
}

class AlbumCollectionScreen extends StatefulWidget {
  final AlbumCollectionType type;
  final String? customTitle;
  final List<Album>? initialAlbums;
  final Future<List<Album>> Function(BuildContext context)? customFetcher;
  final bool startInSelectionMode;

  const AlbumCollectionScreen({
    super.key,
    required this.type,
    this.customTitle,
    this.initialAlbums,
    this.customFetcher,
    this.startInSelectionMode = false,
  });

  const AlbumCollectionScreen.newReleases({
    super.key,
    this.startInSelectionMode = false,
  })  : type = AlbumCollectionType.newest,
        customTitle = null,
        initialAlbums = null,
        customFetcher = null;

  const AlbumCollectionScreen.topRated({
    super.key,
    this.startInSelectionMode = false,
  })  : type = AlbumCollectionType.topRated,
        customTitle = null,
        initialAlbums = null,
        customFetcher = null;

  const AlbumCollectionScreen.starred({
    super.key,
    this.startInSelectionMode = false,
  })  : type = AlbumCollectionType.starred,
        customTitle = null,
        initialAlbums = null,
        customFetcher = null;

  const AlbumCollectionScreen.recent({
    super.key,
    this.startInSelectionMode = false,
  })  : type = AlbumCollectionType.recent,
        customTitle = null,
        initialAlbums = null,
        customFetcher = null;

  @override
  State<AlbumCollectionScreen> createState() => _AlbumCollectionScreenState();
}

class _AlbumCollectionScreenState extends State<AlbumCollectionScreen> {
  List<Album>? _albums;
  List<Album>? _filteredAlbums;
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Set<String> _selectedAlbumIds = {};
  final Map<String, GlobalKey> _albumKeys = {};
  final Map<int, Offset> _pointerPositions = {};
  bool _selecting = false;
  String? _selectedGenre;

  @override
  void initState() {
    super.initState();
    _selecting = widget.startInSelectionMode;
    if (widget.initialAlbums != null) {
      _albums = widget.initialAlbums;
      _filteredAlbums = widget.initialAlbums;
      _isLoading = false;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadAlbums();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAlbums() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      List<Album> albums = [];
      if (widget.customFetcher != null) {
        albums = await widget.customFetcher!(context);
      } else {
        final subsonic = Provider.of<SubsonicService>(context, listen: false);

        switch (widget.type) {
          case AlbumCollectionType.newest:
            albums = await subsonic.getAlbumList(type: 'newest', size: 60);
            break;
          case AlbumCollectionType.topRated:
            albums = await subsonic.getAlbumList(type: 'highest', size: 60);
            break;
          case AlbumCollectionType.starred:
            final starred = await subsonic.getStarred();
            albums = starred.albums;
            break;
          case AlbumCollectionType.recent:
            final library = context.read<LibraryProvider>();
            await library.ensureLibraryLoaded();
            albums = List.from(library.cachedAllAlbums);
            if (albums.isEmpty) {
              albums = await subsonic.getAlbumList(
                type: 'alphabeticalByName',
                size: 500,
              );
            }
            break;
          case AlbumCollectionType.custom:
            albums = widget.initialAlbums ?? [];
            break;
        }
      }

      if (mounted) {
        setState(() {
          _albums = albums;
          _applyFilter(_searchQuery);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilter(String query) {
    _searchQuery = query;
    if (_albums == null) {
      _filteredAlbums = null;
      return;
    }
    final q = query.trim().toLowerCase();
    _filteredAlbums = _albums!.where((album) {
      final matchesSearch = q.isEmpty ||
          album.name.toLowerCase().contains(q) ||
          (album.artist?.toLowerCase().contains(q) ?? false);
      final matchesGenre = _selectedGenre == null ||
          album.genre?.toLowerCase() == _selectedGenre!.toLowerCase();
      return matchesSearch && matchesGenre;
    }).toList();
  }

  List<String> get _availableGenres {
    final values = (_albums ?? const <Album>[])
        .map((album) => album.genre?.trim())
        .whereType<String>()
        .where((genre) => genre.isNotEmpty)
        .toSet()
        .toList();
    values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  void _toggleSelection(Album album) {
    setState(() {
      _selecting = true;
      if (!_selectedAlbumIds.add(album.id)) {
        _selectedAlbumIds.remove(album.id);
      }
    });
  }

  void _startSelection(Album album) {
    setState(() {
      _selecting = true;
      _selectedAlbumIds.add(album.id);
    });
  }

  void _exitSelection() {
    setState(() {
      _selecting = false;
      _selectedAlbumIds.clear();
    });
  }

  void _closeSelection() {
    if (widget.startInSelectionMode) {
      Navigator.pop(context);
    } else {
      _exitSelection();
    }
  }

  Future<void> _addSelectedToCollection() async {
    final collectionId = await showAddAlbumsToCollectionSheet(
      context,
      _selectedAlbumIds,
    );
    if (collectionId == null || !mounted) return;
    final collection =
        context.read<AlbumCollectionService>().byId(collectionId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added to ${collection?.name ?? 'collection'}')),
    );
    if (widget.startInSelectionMode) {
      Navigator.pop(context);
    } else {
      _exitSelection();
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerPositions[event.pointer] = event.position;
    if (_pointerPositions.length >= 2) _selectAlbumsUnderPointers();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointerPositions.containsKey(event.pointer)) return;
    _pointerPositions[event.pointer] = event.position;
    if (_pointerPositions.length >= 2) _selectAlbumsUnderPointers();
  }

  void _onPointerUp(PointerEvent event) {
    _pointerPositions.remove(event.pointer);
  }

  void _selectAlbumsUnderPointers() {
    final newlySelected = <String>{};
    for (final position in _pointerPositions.values) {
      for (final album in _filteredAlbums ?? const <Album>[]) {
        final box = _albumKeys[album.id]?.currentContext?.findRenderObject();
        if (box is! RenderBox || !box.hasSize) continue;
        final rect = box.localToGlobal(Offset.zero) & box.size;
        if (rect.contains(position)) newlySelected.add(album.id);
      }
    }
    if (newlySelected.isEmpty && _selecting) return;
    setState(() {
      _selecting = true;
      _selectedAlbumIds.addAll(newlySelected);
    });
  }

  Future<void> _showGenreFilter() async {
    final genres = _availableGenres;
    final selected = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Filter by genre',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              title: const Text('All genres'),
              trailing: _selectedGenre == null
                  ? const Icon(CupertinoIcons.checkmark)
                  : null,
              onTap: () => Navigator.pop(sheetContext, ''),
            ),
            ...genres.map((genre) => ListTile(
                  title: Text(genre),
                  trailing: _selectedGenre == genre
                      ? const Icon(CupertinoIcons.checkmark)
                      : null,
                  onTap: () => Navigator.pop(sheetContext, genre),
                )),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedGenre = selected.isEmpty ? null : selected;
      _applyFilter(_searchQuery);
    });
  }

  String _getTitle(BuildContext context) {
    if (widget.customTitle != null && widget.customTitle!.isNotEmpty) {
      return widget.customTitle!;
    }
    final l10n = AppLocalizations.of(context);
    switch (widget.type) {
      case AlbumCollectionType.newest:
        return l10n?.categoryNewReleases ?? 'New Releases';
      case AlbumCollectionType.topRated:
        return l10n?.topRated ?? 'Top Rated';
      case AlbumCollectionType.starred:
        return l10n?.likedAlbums ?? 'Liked Albums';
      case AlbumCollectionType.recent:
        return l10n?.albums ?? 'Albums';
      case AlbumCollectionType.custom:
        return 'Albums';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _getTitle(context);
    final isDesktop = ScreenHelper.isDesktop(context);

    return Scaffold(
      body: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerUp,
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _loadAlbums,
              child: CustomScrollView(
                controller: _scrollController,
                dragStartBehavior: DragStartBehavior.down,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ResponsiveBouncingScrollPhysics(),
                ),
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    expandedHeight: 140,
                    leading: _selecting
                        ? IconButton(
                            tooltip: widget.startInSelectionMode
                                ? 'Back to collection'
                                : 'Cancel selection',
                            onPressed: _closeSelection,
                            icon: const Icon(CupertinoIcons.clear),
                          )
                        : null,
                    actions: _selecting
                        ? [
                            IconButton(
                              tooltip: 'Select all',
                              onPressed: () => setState(() {
                                _selectedAlbumIds.addAll(
                                  (_filteredAlbums ?? const <Album>[])
                                      .map((album) => album.id),
                                );
                              }),
                              icon: const Icon(
                                  CupertinoIcons.checkmark_alt_circle),
                            ),
                            IconButton(
                              tooltip: 'Add to collection',
                              onPressed: _selectedAlbumIds.isEmpty
                                  ? null
                                  : _addSelectedToCollection,
                              icon: const Icon(
                                  CupertinoIcons.square_stack_3d_up_fill),
                            ),
                          ]
                        : [
                            IconButton(
                              tooltip: 'Filter by genre',
                              onPressed: _showGenreFilter,
                              icon: Icon(_selectedGenre == null
                                  ? CupertinoIcons.slider_horizontal_3
                                  : CupertinoIcons.slider_horizontal_3),
                            ),
                          ],
                    flexibleSpace: FlexibleSpaceBar(
                      title: Text(
                        _selecting
                            ? '${_selectedAlbumIds.length} selected'
                            : title,
                        style: theme.appBarTheme.titleTextStyle ??
                            const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      titlePadding: EdgeInsets.only(
                        left: isDesktop ? 64 : 52,
                        bottom: 16,
                      ),
                    ),
                  ),
                  if (!_isLoading && _error == null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                        child: Column(
                          children: [
                            CupertinoSearchTextField(
                              controller: _searchController,
                              placeholder: 'Search albums or artists',
                              onChanged: (value) => setState(() {
                                _applyFilter(value);
                              }),
                            ),
                            if (_selectedGenre != null) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: InputChip(
                                  label: Text(_selectedGenre!),
                                  avatar: const Icon(CupertinoIcons.music_note,
                                      size: 16),
                                  onDeleted: () => setState(() {
                                    _selectedGenre = null;
                                    _applyFilter(_searchQuery);
                                  }),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  if (_isLoading)
                    _buildLoadingGrid(context)
                  else if (_error != null)
                    _buildErrorState(theme)
                  else if (_filteredAlbums == null || _filteredAlbums!.isEmpty)
                    _buildEmptyState(theme)
                  else
                    _buildAlbumGrid(context),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
            if (!_isLoading &&
                _filteredAlbums != null &&
                _filteredAlbums!.length >= 8)
              _buildAlphabetSidebar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingGrid(BuildContext context) {
    final columns = _getColumnCount(context);
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.78,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => const AlbumCardShimmer(size: double.infinity),
          childCount: columns * 4,
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: AppTheme.lightSecondaryText,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.errorLoadingAlbums,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadAlbums,
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context)!.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.album_outlined,
              size: 64,
              color: AppTheme.lightSecondaryText,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noAlbumsFound,
              style: theme.textTheme.headlineSmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumGrid(BuildContext context) {
    final columns = _getColumnCount(context);
    final albums = _filteredAlbums!;

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.76,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final album = albums[index];
            return AlbumCard(
              key: _albumKeys.putIfAbsent(album.id, GlobalKey.new),
              album: album,
              size: double.infinity,
              selectionMode: _selecting,
              selected: _selectedAlbumIds.contains(album.id),
              onTap: () {
                if (_selecting) {
                  _toggleSelection(album);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AlbumScreen(albumId: album.id),
                    ),
                  );
                }
              },
              onLongPress: () => _startSelection(album),
            );
          },
          childCount: albums.length,
        ),
      ),
    );
  }

  int _getColumnCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return AlbumGridLayout.columns(context, width);
  }

  void _scrollToLetter(String letter) {
    if (_filteredAlbums == null || _filteredAlbums!.isEmpty) return;

    int targetIndex = -1;
    if (letter == '#') {
      targetIndex = _filteredAlbums!.indexWhere((a) {
        final first =
            a.name.trim().isNotEmpty ? a.name.trim()[0].toUpperCase() : '';
        return first.isNotEmpty && !RegExp(r'[A-Z]').hasMatch(first);
      });
    } else {
      targetIndex = _filteredAlbums!.indexWhere((a) {
        return a.name.trim().toUpperCase().startsWith(letter);
      });
    }

    if (targetIndex >= 0 && _scrollController.hasClients) {
      final columns = _getColumnCount(context);
      final width = MediaQuery.of(context).size.width;
      final itemWidth = (width - 32 - (columns - 1) * 16) / columns;
      final itemHeight = itemWidth / 0.76 + 16;
      final row = targetIndex ~/ columns;
      final targetOffset = (row * itemHeight).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.jumpTo(targetOffset);
    }
  }

  Widget _buildAlphabetSidebar(BuildContext context) {
    final alphabet = <String>[
      '#',
      ...List.generate(26, (i) => String.fromCharCode(65 + i)),
    ];

    return Positioned(
      right: 4,
      top: 130,
      bottom: 90,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: alphabet.map((letter) {
                return InkWell(
                  onTap: () => _scrollToLetter(letter),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 1.0, horizontal: 4),
                    child: Text(
                      letter,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class LikedAlbumsScreen extends StatelessWidget {
  const LikedAlbumsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AlbumCollectionScreen.starred();
  }
}

class NewReleasesScreen extends StatelessWidget {
  const NewReleasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AlbumCollectionScreen.newReleases();
  }
}

class TopRatedScreen extends StatelessWidget {
  const TopRatedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AlbumCollectionScreen.topRated();
  }
}

class AlbumsScreen extends StatelessWidget {
  const AlbumsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AlbumCollectionScreen.recent();
  }
}
