import 'package:flutter_test/flutter_test.dart';
import 'package:playbox/api.dart';
import 'package:playbox/downloads_api.dart';

import 'fake_server.dart';

void main() {
  test('searchTitles merges movies then shows', () async {
    final fs = FakeServer({
      'MovieSearch': (_) => {
            'movieSearch': [
              {'id': 1, 'title': 'M', 'year': 2020, 'overview': 'o', 'posterURL': null}
            ]
          },
      'TvSearch': (_) => {
            'tvSearch': [
              {'id': 2, 'name': 'S', 'year': 2019, 'overview': null, 'posterURL': 'p'}
            ]
          },
    });
    final r = await PlayboxApi('http://x', client: fs.client).searchTitles('q');
    expect(r.map((e) => e.title), ['M', 'S']);
    expect(r.map((e) => e.isMovie), [true, false]);
  });

  test('bestTorrent returns pick with alternatives, null when none', () async {
    var empty = false;
    final fs = FakeServer({
      'BestTorrent': (v) => {
            'bestTorrent': empty
                ? null
                : {
                    ...sourceJson('aaa'),
                    'alternatives': [sourceJson('bbb', packTitle: 'Pack')]
                  }
          },
    });
    final api = PlayboxApi('http://x', client: fs.client);
    final ctx = SearchContext('Show S01E02', 'tv', 5, '2020-01-01');
    final p = await api.bestTorrent(ctx);
    expect(p!.best.infoHash, 'aaa');
    expect(p.all.length, 2);
    expect(p.alternatives.first.packTitle, 'Pack');
    expect(fs.calls.single.vars['term'], 'Show S01E02');
    expect(fs.calls.single.vars['airDate'], '2020-01-01');
    empty = true;
    expect(await api.bestTorrent(ctx), isNull);
  });

  test('addTorrent sends magnet, filePath, search and optional replaces', () async {
    final fs = FakeServer({'AddTorrent': (_) => {'addTorrent': true}});
    final api = PlayboxApi('http://x', client: fs.client);
    final src = TorrentSource.fromJson(sourceJson('aaa', filePath: 'a/b.mkv'));
    final ctx = SearchContext('Show S01E01', 'tv', 5);
    await api.addTorrent(src, ctx);
    var v = fs.calls.last.vars;
    expect(v['magnet'], 'magnet:?xt=urn:btih:aaa');
    expect(v['filePath'], 'a/b.mkv');
    expect(v['search'], {'term': 'Show S01E01', 'mediaType': 'tv', 'tmdbId': 5});
    expect(v.containsKey('replaces'), false);
    final old = Download.fromJson(torrentJson('old', filePath: 'x.mkv'));
    await api.addTorrent(src, ctx, replaces: old);
    v = fs.calls.last.vars;
    expect(v['replaces'], {'infoHash': 'old', 'filePath': 'x.mkv'});
  });

  test('remove, pause and resume send the right variables', () async {
    final fs = FakeServer({
      'RemoveTorrent': (_) => {'removeTorrent': true},
      'PauseTorrent': (_) => {'pauseTorrent': true},
      'ResumeTorrent': (_) => {'resumeTorrent': true},
    });
    final api = PlayboxApi('http://x', client: fs.client);
    final d = Download.fromJson(torrentJson('h1', filePath: 'f'));
    await api.removeDownload(d);
    await api.pauseDownload(d);
    await api.resumeDownload(d);
    expect(fs.calls[0].vars, {'infoHash': 'h1', 'filePath': 'f'});
    expect(fs.calls[1].vars, {'infoHash': 'h1'});
    expect(fs.calls[2].op, 'ResumeTorrent');
  });

  test('downloads parses the list', () async {
    final fs = FakeServer({
      'Torrents': (_) => {
            'torrents': [torrentJson('h', size: 200, done: 50)]
          }
    });
    final l = await PlayboxApi('http://x', client: fs.client).downloads();
    expect(l.single.fraction, 0.25);
    expect(l.single.downloadSpeed, 524288);
  });

  test('errors: refusal, unreachable, graphql message', () async {
    final denied = FakeServer({}, status: 403);
    await expectLater(PlayboxApi('http://x', client: denied.client).downloads(),
        throwsA(isA<ApiException>().having((e) => e.refused, 'refused', true)));
    final fs = FakeServer({
      'Torrents': (_) => throw 'this profile is not allowed to download'
    });
    await expectLater(PlayboxApi('http://x', client: fs.client).downloads(),
        throwsA(isA<ApiException>().having((e) => e.refused, 'refused', true)));
    expect(looksRefused('disk full'), false);
  });

  test('formatters', () {
    expect(formatSpeed(524288), '512 KB/s');
    expect(formatSpeed(3 * 1024 * 1024), '3.0 MB/s');
    expect(formatEta(null), 'Calculating...');
    expect(formatEta(30), '30 sec left');
    expect(formatEta(600), '10 min left');
    expect(formatBytes(2147483648), '2.00 GiB');
    expect(formatBytes(5 * 1024 * 1024), '5 MiB');
  });
}
