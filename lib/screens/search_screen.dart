import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../downloads_api.dart';
import 'add_sheet.dart';
import 'player_screen.dart';
import 'show_screen.dart';
import 'widgets.dart';

class SearchScreen extends StatefulWidget {
  final PlayboxApi api;
  const SearchScreen({super.key, required this.api});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctl = TextEditingController();
  Future<List<SearchResult>>? _results;
  String _q = '';

  void _search([String? q]) {
    final t = (q ?? _ctl.text).trim();
    if (t.isEmpty) return;
    setState(() {
      _q = t;
      _results = widget.api.searchTitles(t);
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: TextField(
            controller: _ctl,
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            decoration: InputDecoration(
              hintText: 'Search movies and shows',
              border: InputBorder.none,
              suffixIcon: IconButton(
                  icon: const Icon(Icons.search), onPressed: _search),
            ),
          ),
        ),
        body: _results == null
            ? const Center(child: Text('Search for a movie or show to add.'))
            : FutureBuilder<List<SearchResult>>(
                future: _results,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    final e = snap.error;
                    return ErrorView(
                        message: e is ApiException && e.refused
                            ? 'The server refused this search: ${e.message}'
                            : '$e',
                        onRetry: () => _search(_q),
                        showSettings: e is ApiException && e.unreachable);
                  }
                  final list = snap.data!;
                  if (list.isEmpty) {
                    return ErrorView(
                        message: 'No titles found for "$_q".',
                        onRetry: () => _search(_q),
                        showSettings: false);
                  }
                  return RefreshIndicator(
                    onRefresh: () async => _search(_q),
                    child: GridView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 170,
                        childAspectRatio: 0.55,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _ResultTile(
                          api: widget.api, r: list[i]),
                    ),
                  );
                },
              ),
      );
}

class _ResultTile extends StatelessWidget {
  final PlayboxApi api;
  final SearchResult r;
  const _ResultTile({required this.api, required this.r});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TitleScreen(api: api, result: r)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(width: double.infinity, child: Poster(r.posterUrl)))),
          const SizedBox(height: 4),
          Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          Text('${r.isMovie ? 'Movie' : 'Show'}${r.year != null ? ' · ${r.year}' : ''}',
              style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ]),
      );
}

/// Title page for a search result. Shows reuse the episode list; movies get an Add button.
class TitleScreen extends StatefulWidget {
  final PlayboxApi api;
  final SearchResult result;
  const TitleScreen({super.key, required this.api, required this.result});
  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> {
  late Future<LibraryItem?> _owned;

  @override
  void initState() {
    super.initState();
    _owned = _lookup();
  }

  Future<LibraryItem?> _lookup() async {
    final lib = await widget.api.library();
    for (final i in lib) {
      if (i.id == widget.result.id && i.isMovie == widget.result.isMovie) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    return FutureBuilder<LibraryItem?>(
      future: _owned,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
              appBar: AppBar(title: Text(r.title)),
              body: const Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return Scaffold(
              appBar: AppBar(title: Text(r.title)),
              body: ErrorView(
                  message: '${snap.error}',
                  onRetry: () => setState(() => _owned = _lookup())));
        }
        final owned = snap.data;
        if (!r.isMovie) {
          return ShowScreen(
              api: widget.api,
              item: owned ??
                  LibraryItem(
                      id: r.id, name: r.title, year: r.year, posterUrl: r.posterUrl));
        }
        return _MovieBody(api: widget.api, r: r, owned: owned);
      },
    );
  }
}

class _MovieBody extends StatelessWidget {
  final PlayboxApi api;
  final SearchResult r;
  final LibraryItem? owned;
  const _MovieBody({required this.api, required this.r, required this.owned});

  Future<void> _add(BuildContext context) async {
    final term = r.year != null ? '${r.title} ${r.year}' : r.title;
    final added = await showAddSheet(
        context, api, SearchContext(term, 'movie', r.id),
        label: term);
    if (added && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Added to Downloads')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(r.title)),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Center(
            child: SizedBox(
                width: 200,
                height: 300,
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(8), child: Poster(r.posterUrl))),
          ),
          const SizedBox(height: 12),
          Text('${r.title}${r.year != null ? ' (${r.year})' : ''}',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (r.overview != null && r.overview!.isNotEmpty) Text(r.overview!),
          const SizedBox(height: 16),
          if (owned?.movieSceneId != null)
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => PlayerScreen(
                        title: r.title, url: api.streamUrl(owned!.movieSceneId!))),
              ),
            )
          else
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add'),
              onPressed: () => _add(context),
            ),
        ]),
      );
}
