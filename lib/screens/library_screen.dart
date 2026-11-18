import 'package:material_ui/material_ui.dart';

import '../api.dart';
import 'player_screen.dart';
import 'settings_screen.dart';
import 'show_screen.dart';
import 'widgets.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late Future<(PlayboxApi, List<LibraryItem>)> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(PlayboxApi, List<LibraryItem>)> _load() async {
    final api = await PlayboxApi.load();
    return (api, await api.library());
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Playbox'), actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
              _reload();
            },
          ),
        ]),
        body: FutureBuilder(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ErrorView(message: '${snap.error}', onRetry: _reload);
            }
            final (api, items) = snap.data!;
            if (items.isEmpty) {
              return ErrorView(
                  message: 'The library is empty.',
                  onRetry: _reload,
                  showSettings: false);
            }
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 170,
                  childAspectRatio: 0.55,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: items.length,
                itemBuilder: (_, i) => _Tile(api: api, item: items[i]),
              ),
            );
          },
        ),
      );
}

class _Tile extends StatelessWidget {
  final PlayboxApi api;
  final LibraryItem item;
  const _Tile({required this.api, required this.item});

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => item.isMovie
                ? PlayerScreen(
                    title: item.name, url: api.streamUrl(item.movieSceneId!))
                : ShowScreen(api: api, item: item),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(8), child: Poster(item.posterUrl))),
          const SizedBox(height: 4),
          Text(item.name,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Text(item.yearRange ?? (item.year?.toString() ?? ''),
              style: const TextStyle(fontSize: 11, color: Colors.white54)),
        ]),
      );
}
