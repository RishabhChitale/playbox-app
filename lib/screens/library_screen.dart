import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../app_state.dart';
import '../local_store.dart';
import 'player_screen.dart';
import 'settings_screen.dart';
import 'show_screen.dart';
import 'widgets.dart';

const _allId = '';
const _favId = 'fav';

class LibraryScreen extends StatefulWidget {
  final PlayboxApi api;
  final VoidCallback? onSettingsChanged;
  const LibraryScreen({super.key, required this.api, this.onSettingsChanged});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late Future<List<LibraryItem>> _future;
  List<Category> _categories = [];
  String _selected = _allId;
  final Map<String, Set<String>> _sceneIds = {};
  bool _catLoading = false;
  bool _catFailed = false;
  bool _init = false;

  AppState get _app => AppScope.of(context);

  @override
  void initState() {
    super.initState();
    _future = widget.api.library();
    _loadCategories();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_init) {
      _init = true;
      _selected = _app.store.lastCategory;
      if (_selected.isNotEmpty && _selected != _favId) _loadScenes(_selected);
    }
  }

  Future<void> _loadCategories() async {
    try {
      final c = await widget.api.categories();
      if (mounted) setState(() => _categories = c);
    } catch (_) {
      // Categories are optional; the bar then shows only All and Favorites.
    }
  }

  Future<void> _loadScenes(String id) async {
    if (_sceneIds.containsKey(id)) return;
    setState(() {
      _catLoading = true;
      _catFailed = false;
    });
    try {
      final ids = await widget.api.sceneIdsInCategory(id);
      if (mounted) _sceneIds[id] = ids;
    } catch (_) {
      if (mounted) _catFailed = true;
    }
    if (mounted) setState(() => _catLoading = false);
  }

  Future<void> _select(String id) async {
    setState(() => _selected = id);
    await _app.store.setLastCategory(id);
    if (id.isNotEmpty && id != _favId) await _loadScenes(id);
  }

  void _reload() => setState(() {
        _sceneIds.clear();
        _future = widget.api.library();
        _loadCategories();
        if (_selected.isNotEmpty && _selected != _favId) _loadScenes(_selected);
      });

  Widget _chip(String id, String label, {IconData? icon}) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          avatar: icon == null ? null : Icon(icon, size: 16),
          label: Text(label),
          selected: _selected == id,
          onSelected: (_) => _select(id),
        ),
      );

  Widget _chipBar() => SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          children: [
            _chip(_allId, 'All'),
            _chip(_favId, 'Favorites', icon: Icons.favorite),
            for (final c in _categories) _chip(c.id, c.name),
          ],
        ),
      );

  void _open(LibraryItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => item.isMovie
            ? PlayerScreen(
                title: item.name,
                url: widget.api.streamUrl(item.movieSceneId!),
                sceneId: item.movieSceneId,
                api: widget.api)
            : ShowScreen(api: widget.api, item: item),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _resume(ContinueEntry e) {
    final item = e.item;
    final title = e.label == null ? item.name : '${item.name} · ${e.label}';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
            title: title,
            url: widget.api.streamUrl(e.sceneId),
            sceneId: e.sceneId,
            api: widget.api),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  Widget _continueRow(List<ContinueEntry> entries) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 6),
        child: Text('Continue watching',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      SizedBox(
        height: 190,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final e = entries[i];
            return SizedBox(
              width: 100,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _resume(e),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(fit: StackFit.expand, children: [
                        Poster(e.item.posterUrl),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: LinearProgressIndicator(
                              value: e.progress.fraction, minHeight: 4),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(e.item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  if (e.label != null)
                    Text(e.label!,
                        style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ]),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 6),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final app = _app;
    return Scaffold(
      appBar: AppBar(title: const Text('Playbox'), actions: [
        IconButton(
          tooltip: 'Settings',
          icon: const Icon(Icons.settings),
          onPressed: () async {
            await Navigator.push(
                context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            if (widget.onSettingsChanged != null) {
              widget.onSettingsChanged!();
            } else {
              _reload();
            }
          },
        ),
      ]),
      body: FutureBuilder<List<LibraryItem>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SkeletonGrid();
          }
          if (snap.hasError) {
            return ErrorView(message: '${snap.error}', onRetry: _reload);
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: const EmptyView(
                  icon: Icons.video_library_outlined,
                  message: 'The library is empty.',
                  hint: 'Search for something and add it to Downloads.'),
            );
          }
          final fav = _selected == _favId;
          final ids = (_selected.isEmpty || fav) ? null : _sceneIds[_selected];
          final shown = filterLibrary(items,
              sceneIds: ids, favoritesOnly: fav, favorites: app.store.favorites);
          final cont = continueWatching(items, app.store.progress, app.store.progressOrder);
          final waiting = _selected.isNotEmpty && !fav && ids == null;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _chipBar()),
                if (cont.isNotEmpty && _selected.isEmpty)
                  SliverToBoxAdapter(child: _continueRow(cont)),
                if (waiting && _catLoading)
                  const SliverFillRemaining(child: SkeletonGrid())
                else if (waiting && _catFailed)
                  SliverFillRemaining(
                      hasScrollBody: false,
                      child: ErrorView(
                          message: 'Could not load this category.',
                          onRetry: () => _loadScenes(_selected),
                          showSettings: false))
                else if (shown.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(fav
                          ? 'No favorites yet. Tap the heart on a title.'
                          : 'Nothing in this category yet.'),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(12),
                    sliver: SliverGrid.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 170,
                        childAspectRatio: 0.55,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: shown.length,
                      itemBuilder: (_, i) => _Tile(
                        item: shown[i],
                        favorite: app.store.isFavorite(shown[i].key),
                        onTap: () => _open(shown[i]),
                        onHeart: () async {
                          await app.store.toggleFavorite(shown[i].key);
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final LibraryItem item;
  final bool favorite;
  final VoidCallback onTap, onHeart;
  const _Tile(
      {required this.item,
      required this.favorite,
      required this.onTap,
      required this.onHeart});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(fit: StackFit.expand, children: [
              Poster(item.posterUrl),
              if (favorite)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(Icons.favorite, size: 18, color: Colors.redAccent),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 4),
        Text(item.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        Text(item.yearRange ?? (item.year?.toString() ?? ''),
            style: TextStyle(fontSize: 11, color: muted)),
      ]),
    );
  }
}
