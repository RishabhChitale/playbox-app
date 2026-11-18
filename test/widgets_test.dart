import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playbox/api.dart';
import 'package:playbox/downloads_api.dart';
import 'package:playbox/screens/add_sheet.dart';
import 'package:playbox/screens/downloads_screen.dart';
import 'package:playbox/screens/search_screen.dart';

import 'fake_server.dart';

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 5; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<void> mount(WidgetTester t, Widget w) async {
  await t.pumpWidget(MaterialApp(home: w));
  await settle(t);
}

Future<void> unmount(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
}

PlayboxApi apiFor(FakeServer fs) => PlayboxApi('http://x', client: fs.client);

void main() {
  final ctx = SearchContext('Show S01E01', 'tv', 5, '2020-01-01');

  testWidgets('add sheet shows best source, alternatives, and adds the chosen one',
      (t) async {
    final fs = FakeServer({
      'BestTorrent': (_) => {
            'bestTorrent': {
              ...sourceJson('aaa', qualityNote: 'low seeders'),
              'alternatives': [sourceJson('bbb', filePath: 'p/e.mkv', packTitle: 'BigPack')]
            }
          },
      'AddTorrent': (_) => {'addTorrent': true},
    });
    await mount(t, Scaffold(body: AddSheet(api: apiFor(fs), ctx: ctx)));
    expect(find.text('Best source'), findsOneWidget);
    expect(find.text('Release aaa'), findsOneWidget);
    expect(find.text('low seeders'), findsOneWidget);
    await t.tap(find.text('Try another source'));
    await settle(t);
    expect(find.text('Release bbb'), findsOneWidget);
    expect(find.textContaining('One file from the pack BigPack'), findsOneWidget);
    await t.tap(find.text('Release bbb'));
    await settle(t);
    expect(find.text('Selected source'), findsOneWidget);
    await t.tap(find.text('Download'));
    await settle(t);
    final v = fs.calls.last.vars;
    expect(fs.calls.last.op, 'AddTorrent');
    expect(v['magnet'], 'magnet:?xt=urn:btih:bbb');
    expect(v['filePath'], 'p/e.mkv');
    expect(v['search'], {
      'term': 'Show S01E01',
      'mediaType': 'tv',
      'tmdbId': 5,
      'airDate': '2020-01-01'
    });
    await unmount(t);
  });

  testWidgets('add sheet: no release and refusal states', (t) async {
    final none = FakeServer({'BestTorrent': (_) => {'bestTorrent': null}});
    await mount(t, Scaffold(body: AddSheet(api: apiFor(none), ctx: ctx)));
    expect(find.text(noReleaseMessage), findsOneWidget);
    expect(find.text('Search again'), findsOneWidget);

    await unmount(t);
    final denied = FakeServer({
      'BestTorrent': (_) => throw 'this profile is not allowed to download'
    });
    await mount(t, Scaffold(body: AddSheet(api: apiFor(denied), ctx: ctx)));
    expect(find.textContaining('The server refused this search'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await unmount(t);
  });

  testWidgets('add sheet shows refusal when adding is refused', (t) async {
    final fs = FakeServer({
      'BestTorrent': (_) => {'bestTorrent': {...sourceJson('aaa'), 'alternatives': []}},
      'AddTorrent': (_) => throw 'profile not allowed',
    });
    await mount(t, Scaffold(body: AddSheet(api: apiFor(fs), ctx: ctx)));
    await t.tap(find.text('Download'));
    await settle(t);
    expect(find.textContaining('The server refused this download'), findsOneWidget);
    await unmount(t);
  });

  testWidgets('downloads screen renders each state', (t) async {
    final fs = FakeServer({
      'Torrents': (_) => {
            'torrents': [
              torrentJson('dl', size: 1000, done: 500),
              {...torrentJson('st', done: 10), 'stalled': true},
              torrentJson('bad', finished: true, done: 1000, corrupt: 'truncated'),
              torrentJson('add', finished: true, done: 1000),
              torrentJson('ok', finished: true, done: 1000, sceneId: '7'),
            ]
          },
    });
    await mount(t, DownloadsScreen(api: apiFor(fs), pollInterval: const Duration(hours: 1)));
    expect(find.textContaining('2 peers'), findsWidgets);
    expect(find.textContaining('512 KB/s'), findsWidgets);
    expect(find.textContaining('(50%)'), findsOneWidget);
    expect(find.textContaining('No data has arrived for a few minutes'), findsOneWidget);
    expect(find.textContaining("corrupt and won't play: truncated"), findsOneWidget);
    expect(find.text('Adding to your library...'), findsOneWidget);
    expect(find.text('Ready to play'), findsOneWidget);
    expect(find.byTooltip('Play'), findsOneWidget);
    await unmount(t);
  });

  testWidgets('remove asks first, says files are kept, cancel does nothing',
      (t) async {
    final fs = FakeServer({
      'Torrents': (_) => {'torrents': [torrentJson('h1', filePath: 'f')]},
      'RemoveTorrent': (_) => {'removeTorrent': true},
    });
    await mount(t, DownloadsScreen(api: apiFor(fs), pollInterval: const Duration(hours: 1)));
    await t.tap(find.byTooltip('Remove'));
    await settle(t);
    expect(find.textContaining('KEPT on disk'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await settle(t);
    expect(fs.count('RemoveTorrent'), 0);
    await t.tap(find.byTooltip('Remove'));
    await settle(t);
    await t.tap(find.text('Remove'));
    await settle(t);
    expect(fs.count('RemoveTorrent'), 1);
    expect(fs.calls.firstWhere((c) => c.op == 'RemoveTorrent').vars,
        {'infoHash': 'h1', 'filePath': 'f'});
    await unmount(t);
  });

  testWidgets('pause and resume send the right operations', (t) async {
    var paused = false;
    final fs = FakeServer({
      'Torrents': (_) => {'torrents': [torrentJson('h1', paused: paused)]},
      'PauseTorrent': (_) {
        paused = true;
        return {'pauseTorrent': true};
      },
      'ResumeTorrent': (_) {
        paused = false;
        return {'resumeTorrent': true};
      },
    });
    await mount(t, DownloadsScreen(api: apiFor(fs), pollInterval: const Duration(hours: 1)));
    await t.tap(find.byTooltip('Pause'));
    await settle(t);
    expect(fs.count('PauseTorrent'), 1);
    expect(find.byTooltip('Resume'), findsOneWidget);
    await t.tap(find.byTooltip('Resume'));
    await settle(t);
    expect(fs.count('ResumeTorrent'), 1);
    await unmount(t);
  });

  testWidgets('polls only while active', (t) async {
    final fs = FakeServer({'Torrents': (_) => {'torrents': []}});
    final api = apiFor(fs);
    const iv = Duration(seconds: 3);
    await mount(t, DownloadsScreen(api: api, active: false, pollInterval: iv));
    await t.pump(const Duration(seconds: 10));
    expect(fs.count('Torrents'), 0);
    await mount(t, DownloadsScreen(api: api, active: true, pollInterval: iv));
    final first = fs.count('Torrents');
    expect(first, greaterThanOrEqualTo(1));
    await t.pump(const Duration(seconds: 7));
    expect(fs.count('Torrents'), greaterThan(first));
    await mount(t, DownloadsScreen(api: api, active: false, pollInterval: iv));
    final stopped = fs.count('Torrents');
    await t.pump(const Duration(seconds: 10));
    expect(fs.count('Torrents'), stopped);
    await unmount(t);
  });

  testWidgets('downloads error shows Retry', (t) async {
    final fs = FakeServer({}, status: 403);
    await mount(t, DownloadsScreen(api: apiFor(fs), pollInterval: const Duration(hours: 1)));
    expect(find.textContaining('The server refused this request'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await unmount(t);
  });

  testWidgets('search lists posters and opens the movie page with Add',
      (t) async {
    final fs = FakeServer({
      'MovieSearch': (_) => {
            'movieSearch': [
              {'id': 1, 'title': 'Alpha', 'year': 2020, 'overview': 'about alpha', 'posterURL': null}
            ]
          },
      'TvSearch': (_) => {'tvSearch': []},
      'TvLibrary': (_) => {'tvLibrary': []},
      'MovieLibrary': (_) => {'movieLibrary': []},
    });
    await mount(t, SearchScreen(api: apiFor(fs)));
    expect(find.text('Search for a movie or show to add.'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'alpha');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await settle(t);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Movie · 2020'), findsOneWidget);
    await t.tap(find.text('Alpha'));
    await settle(t);
    expect(find.text('about alpha'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add'), findsOneWidget);
    await unmount(t);
  });
}
