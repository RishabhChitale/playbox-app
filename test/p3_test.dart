import 'package:material_ui/material_ui.dart' show ThemeMode, Brightness;
import 'package:flutter_test/flutter_test.dart';
import 'package:playbox/api.dart';
import 'package:playbox/app_state.dart';
import 'package:playbox/local_store.dart';
import 'package:playbox/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_server.dart';

LibraryItem movie(int id, String scene) =>
    LibraryItem(id: id, name: 'M$id', movieSceneId: scene);
LibraryItem show(int id, List<Episode> eps) =>
    LibraryItem(id: id, name: 'S$id', episodes: eps);
Episode ep(int s, int e, String scene) => Episode(s, e, scene, const []);

void main() {
  group('categories api', () {
    test('categories keeps only top-level with children', () async {
      final fs = FakeServer({
        'FindCategories': (_) => {
              'findCategories': {
                'count': 3,
                'categories': [
                  {
                    'id': '1',
                    'name': 'Shows',
                    'parent_category': null,
                    'child_categories': [
                      {'id': '3', 'name': 'Kid'}
                    ]
                  },
                  {'id': '2', 'name': 'Movies', 'parent_category': null, 'child_categories': []},
                  {'id': '3', 'name': 'Kid', 'parent_category': {'id': '1'}, 'child_categories': []},
                ]
              }
            },
      });
      final api = PlayboxApi('http://x', client: fs.client);
      final c = await api.categories();
      expect(c.map((e) => e.name), ['Shows', 'Movies']);
      expect(c.first.children.single.name, 'Kid');
    });

    test('sceneIdsInCategory sends the id; saveActivity and ApiKey header', () async {
      final fs = FakeServer({
        'SceneIdsInCategory': (v) => {
              'findScenes': {
                'scenes': [
                  {'id': '5'},
                  {'id': '6'}
                ]
              }
            },
        'SaveActivity': (v) => {'sceneSaveActivity': true},
      });
      final api = PlayboxApi('http://x', client: fs.client, apiKey: 'k');
      expect(await api.sceneIdsInCategory('9'), {'5', '6'});
      expect(fs.calls.first.vars['id'], '9');
      expect(await api.saveActivity('5', 12.5, 3), true);
      expect(fs.calls.last.vars['resume'], 12.5);
      // failures are swallowed
      final bad = PlayboxApi('http://x', client: FakeServer({}, status: 500).client);
      expect(await bad.saveActivity('5', 1, 1), false);
    });
  });

  group('filterLibrary', () {
    final items = [
      movie(1, 'a'),
      show(2, [ep(1, 1, 'b'), ep(1, 2, 'c')]),
      show(3, [ep(1, 1, 'd')]),
    ];
    test('no filter returns all', () {
      expect(filterLibrary(items).length, 3);
    });
    test('category matches movie scene or any episode scene', () {
      final r = filterLibrary(items, sceneIds: {'a', 'c'});
      expect(r.map((i) => i.id), [1, 2]);
    });
    test('favorites only', () {
      final r = filterLibrary(items, favoritesOnly: true, favorites: {'tv:3'});
      expect(r.map((i) => i.id), [3]);
    });
  });

  group('progress and continue watching', () {
    test('progress math', () {
      expect(const Progress(95000, 100000).watched, true);
      expect(const Progress(90000, 100000).watched, false);
      expect(const Progress(5000, 100000).inProgress, false);
      expect(const Progress(5000, 100000).resumeFrom, Duration.zero);
      expect(const Progress(30000, 100000).resumeFrom, const Duration(seconds: 30));
      expect(const Progress(95000, 100000).resumeFrom, Duration.zero);
      expect(const Progress(1, 0).fraction, 0);
    });

    test('continueWatching orders newest first, one per title, skips watched', () {
      final items = [
        movie(1, 'a'),
        show(2, [ep(1, 1, 'b'), ep(1, 2, 'c')]),
        movie(3, 'd'),
      ];
      final prog = {
        'a': const Progress(30000, 100000),
        'b': const Progress(20000, 100000),
        'c': const Progress(40000, 100000),
        'd': const Progress(99000, 100000),
      };
      final r = continueWatching(items, prog, ['a', 'b', 'd', 'c']);
      expect(r.map((e) => e.item.id), [2, 1]);
      expect(r.first.sceneId, 'c');
      expect(r.first.label, 'S1 E2');
    });
  });

  group('local store', () {
    test('favorites toggle and persist', () async {
      SharedPreferences.setMockInitialValues({});
      var s = await LocalStore.open();
      expect(await s.toggleFavorite('tv:1'), true);
      expect(s.isFavorite('tv:1'), true);
      s = await LocalStore.open();
      expect(s.isFavorite('tv:1'), true);
      expect(await s.toggleFavorite('tv:1'), false);
      expect(s.isFavorite('tv:1'), false);
    });

    test('progress saved, resumed and cleared; favorites kept', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await LocalStore.open();
      await s.toggleFavorite('movie:1');
      await s.saveProgress('a', 1000, 5000);
      await s.saveProgress('b', 2000, 5000);
      await s.saveProgress('a', 3000, 5000);
      expect(s.progress['a']!.positionMs, 3000);
      expect(s.progressOrder, ['b', 'a']);
      await s.setLastCategory('7');
      await s.clearCache();
      expect(s.progress, isEmpty);
      expect(s.lastCategory, '');
      expect(s.isFavorite('movie:1'), true);
    });

    test('theme, palette and api key persist', () async {
      SharedPreferences.setMockInitialValues({});
      var st = AppState(await LocalStore.open());
      expect(st.palette, palettePlayboxId);
      await st.setMode('light');
      await st.setPalette(paletteTunaId);
      await st.store.setApiKey('abc');
      st = AppState(await LocalStore.open());
      expect(st.mode, ThemeMode.light);
      expect(st.palette, paletteTunaId);
      expect(st.store.apiKey, 'abc');
      await st.store.setApiKey('');
      expect(st.store.apiKey, '');
    });

    test('both palettes build in both brightnesses', () {
      for (final p in [palettePlayboxId, paletteTunaId]) {
        for (final b in Brightness.values) {
          expect(buildTheme(p, b).brightness, b);
        }
      }
    });
  });
}
