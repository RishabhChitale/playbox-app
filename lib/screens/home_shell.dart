import 'package:material_ui/material_ui.dart';

import '../api.dart';
import 'downloads_screen.dart';
import 'library_screen.dart';
import 'search_screen.dart';
import 'widgets.dart';

/// Bottom navigation: Library / Search / Downloads.
class HomeShell extends StatefulWidget {
  /// Injectable for tests; otherwise loaded from saved settings.
  final PlayboxApi? api;
  const HomeShell({super.key, this.api});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late Future<PlayboxApi> _api;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _api = _load();
  }

  Future<PlayboxApi> _load() async => widget.api ?? await PlayboxApi.load();
  void _reload() => setState(() => _api = _load());

  @override
  Widget build(BuildContext context) => FutureBuilder<PlayboxApi>(
        future: _api,
        builder: (context, snap) {
          if (!snap.hasData) {
            return snap.hasError
                ? Scaffold(body: ErrorView(message: '${snap.error}', onRetry: _reload))
                : const Scaffold(body: SafeArea(child: SkeletonGrid()));
          }
          final api = snap.data!;
          return Scaffold(
            body: IndexedStack(index: _tab, children: [
              LibraryScreen(key: ValueKey(api.baseUrl), api: api, onSettingsChanged: _reload),
              SearchScreen(api: api),
              DownloadsScreen(api: api, active: _tab == 2),
            ]),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.video_library_outlined), label: 'Library'),
                NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
                NavigationDestination(icon: Icon(Icons.download_outlined), label: 'Downloads'),
              ],
            ),
          );
        },
      );
}
