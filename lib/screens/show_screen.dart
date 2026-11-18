import 'package:material_ui/material_ui.dart';

import '../api.dart';
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

  void _pick(ShowInfo info, int season) {
    setState(() {
      _season = season;
      _episodes = widget.api.seasonEpisodes(widget.item.id, season);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.item.name)),
        body: FutureBuilder<ShowInfo>(
          future: _show,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ErrorView(
                  message: '${snap.error}',
                  onRetry: () => setState(
                      () => _show = widget.api.show(widget.item.id)));
            }
            final info = snap.data!;
            // Default to the first season that has a downloaded episode.
            if (_season == null && info.seasons.isNotEmpty) {
              final have = widget.item.episodes.map((e) => e.season).toSet();
              final first = info.seasons.firstWhere(
                  (s) => have.contains(s.number),
                  orElse: () => info.seasons.first);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _season == null) _pick(info, first.number);
              });
            }
            return ListView(children: [
              if (info.overview != null && info.overview!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(info.overview!,
                      maxLines: 5, overflow: TextOverflow.ellipsis),
                ),
              SizedBox(
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
                          onSelected: (_) => _pick(info, s.number),
                        ),
                      ),
                  ],
                ),
              ),
              if (_episodes != null)
                FutureBuilder<List<EpisodeInfo>>(
                  future: _episodes,
                  builder: (context, es) {
                    if (es.connectionState != ConnectionState.done) {
                      return const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()));
                    }
                    if (es.hasError) {
                      return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('${es.error}'));
                    }
                    return Column(children: [
                      for (final e in es.data!) _row(e),
                    ]);
                  },
                ),
            ]);
          },
        ),
      );

  Widget _row(EpisodeInfo e) {
    final dl = _downloaded(_season!, e.number);
    final title = 'S${_season!.toString().padLeft(2, '0')}E'
        '${e.number.toString().padLeft(2, '0')}  ${e.name}';
    final sub = [
      if (e.airDate != null) e.airDate!,
      if (e.runtime != null) '${e.runtime} min',
      if (dl == null) 'not downloaded',
    ].join(' · ');
    return Opacity(
      opacity: dl == null ? 0.4 : 1,
      child: ListTile(
        leading: SizedBox(
            width: 80,
            height: 48,
            child: ClipRRect(
                borderRadius: BorderRadius.circular(4), child: Poster(e.stillUrl))),
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(sub),
        trailing: dl == null
            ? null
            : IconButton(
                icon: const Icon(Icons.play_circle_fill, size: 32),
                color: Theme.of(context).colorScheme.primary,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlayerScreen(
                        title: '${widget.item.name} · $title',
                        url: widget.api.streamUrl(dl.sceneId)),
                  ),
                ),
              ),
      ),
    );
  }
}
