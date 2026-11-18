import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../app_state.dart';
import '../downloads_api.dart';
import '../local_store.dart';
import 'add_sheet.dart';
import 'player_screen.dart';
import 'widgets.dart';

class ShowScreen extends StatefulWidget {
  final PlayboxApi api;
  final LibraryItem item;
  const ShowScreen({super.key, required this.api, required this.item});
  @override
  State<ShowScreen> createState() => _ShowScreenState();
}

class _ShowScreenState extends State<ShowScreen> {
  late Future<ShowInfo> _show;
  int? _season;
  Future<List<EpisodeInfo>>? _episodes;

  LocalStore get _store => AppScope.of(context).store;

  @override
  void initState() {
    super.initState();
    _show = widget.api.show(widget.item.id);
  }

  Episode? _downloaded(int season, int number) {
    for (final e in widget.item.episodes) {
      if (e.season == season && e.episode == number) return e;
    }
    return null;
  }

  void _pick(int season) {
    setState(() {
      _season = season;
      _episodes = widget.api.seasonEpisodes(widget.item.id, season);
    });
  }

  Future<void> _toggleFav() async {
    await _store.toggleFavorite(widget.item.key);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final fav = _store.isFavorite(widget.item.key);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: fav ? 'Remove from favorites' : 'Add to favorites',
            icon: Icon(fav ? Icons.favorite : Icons.favorite_border),
            onPressed: _toggleFav,
          ),
        ],
      ),
      body: FutureBuilder<ShowInfo>(
        future: _show,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SkeletonList(count: 6);
          }
          if (snap.hasError) {
            return ErrorView(
                message: '${snap.error}',
                onRetry: () =>
                    setState(() => _show = widget.api.show(widget.item.id)));
          }
          final info = snap.data!;
          if (_season == null && info.seasons.isNotEmpty) {
            final have = widget.item.episodes.map((e) => e.season).toSet();
            final first = info.seasons.firstWhere((s) => have.contains(s.number),
                orElse: () => info.seasons.first);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _season == null) _pick(first.number);
            });
          }
          return ListView(padding: EdgeInsets.zero, children: [
            _header(context, info),
            _seasons(info),
            if (_episodes != null) _episodeList(),
            const SizedBox(height: 24),
          ]);
        },
      ),
    );
  }

  Widget _header(BuildContext context, ShowInfo info) {
    final page = Theme.of(context).scaffoldBackgroundColor;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final range = info.yearRange ?? widget.item.yearRange;
    final backdrop = info.backdropUrl ?? widget.item.posterUrl;
    return Stack(children: [
      SizedBox(
        height: 240,
        width: double.infinity,
        child: Stack(fit: StackFit.expand, children: [
          Poster(backdrop),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, page.withValues(alpha: 0.6), page],
                stops: const [0.2, 0.7, 1],
              ),
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 150, left: 16, right: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            SizedBox(
              width: 100,
              height: 150,
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Poster(widget.item.posterUrl)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.item.name,
                        style: Theme.of(context).textTheme.titleLarge,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                    if (range != null)
                      Text(range, style: TextStyle(color: muted)),
                  ]),
            ),
          ]),
          if (widget.item.genres.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(spacing: 6, runSpacing: 4, children: [
                for (final g in widget.item.genres)
                  Chip(
                      label: Text(g),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero),
              ]),
            ),
          if (info.overview != null && info.overview!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(info.overview!,
                  maxLines: 6, overflow: TextOverflow.ellipsis),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    ]);
  }

  Widget _seasons(ShowInfo info) => SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            for (final s in info.seasons)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(s.number == 0 ? 'Specials' : 'Season ${s.number}'),
                  selected: _season == s.number,
                  onSelected: (_) => _pick(s.number),
                ),
              ),
          ],
        ),
      );

  Widget _episodeList() => FutureBuilder<List<EpisodeInfo>>(
        future: _episodes,
        builder: (context, es) {
          if (es.connectionState != ConnectionState.done) {
            return const Padding(
                padding: EdgeInsets.all(12),
                child: Column(children: [
                  Skeleton(height: 64),
                  SizedBox(height: 8),
                  Skeleton(height: 64),
                  SizedBox(height: 8),
                  Skeleton(height: 64),
                ]));
          }
          if (es.hasError) {
            return Padding(
                padding: const EdgeInsets.all(16),
                child: Text('${es.error}'));
          }
          final list = es.data!;
          if (list.isEmpty) {
            return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No episodes listed for this season.')));
          }
          return Column(children: [for (final e in list) _row(e)]);
        },
      );

  Future<void> _add(EpisodeInfo e) async {
    final code = 'S${_season!.toString().padLeft(2, '0')}E'
        '${e.number.toString().padLeft(2, '0')}';
    final ctx = SearchContext(
        '${widget.item.name} $code', 'tv', widget.item.id, e.airDate);
    final added = await showAddSheet(context, widget.api, ctx,
        label: '${widget.item.name} $code');
    if (added && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Added to Downloads')));
    }
  }

  Future<void> _play(Episode dl, String title) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
            title: '${widget.item.name} · $title',
            url: widget.api.streamUrl(dl.sceneId),
            sceneId: dl.sceneId,
            api: widget.api),
      ),
    );
    if (mounted) setState(() {});
  }

  Widget _row(EpisodeInfo e) {
    final dl = _downloaded(_season!, e.number);
    final prog = dl == null ? null : _store.progress[dl.sceneId];
    final title = 'S${_season!.toString().padLeft(2, '0')}E'
        '${e.number.toString().padLeft(2, '0')}  ${e.name}';
    final sub = [
      if (e.airDate != null) e.airDate!,
      if (e.runtime != null) '${e.runtime} min',
      if (dl == null) 'not downloaded',
      if (prog != null && prog.watched) 'watched',
    ].join(' · ');
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: dl == null ? 0.55 : 1,
      child: ListTile(
        leading: SizedBox(
          width: 80,
          height: 48,
          child: Stack(fit: StackFit.expand, children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(4), child: Poster(e.stillUrl)),
            if (prog != null && prog.fraction > 0)
              Align(
                alignment: Alignment.bottomCenter,
                child: LinearProgressIndicator(
                    value: prog.watched ? 1 : prog.fraction, minHeight: 3),
              ),
          ]),
        ),
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(sub),
        trailing: dl == null
            ? TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add'),
                onPressed: () => _add(e),
              )
            : IconButton(
                tooltip: 'Play',
                icon: Icon(
                    prog != null && prog.watched
                        ? Icons.check_circle
                        : Icons.play_circle_fill,
                    size: 32),
                color: scheme.primary,
                onPressed: () => _play(dl, title),
              ),
      ),
    );
  }
}
