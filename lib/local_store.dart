import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

/// Playback position for one scene.
class Progress {
  final int positionMs;
  final int durationMs;
  const Progress(this.positionMs, this.durationMs);

  double get fraction =>
      durationMs <= 0 ? 0 : (positionMs / durationMs).clamp(0.0, 1.0);

  /// More than 90% played counts as watched.
  bool get watched => durationMs > 0 && fraction > 0.9;

  /// Started (more than 10 s in) but not finished.
  bool get inProgress => positionMs > 10000 && !watched;

  /// Where to resume: nothing for watched or barely-started items.
  Duration get resumeFrom =>
      inProgress ? Duration(milliseconds: positionMs) : Duration.zero;

  Map<String, dynamic> toJson() => {'p': positionMs, 'd': durationMs};
  static Progress fromJson(Map<String, dynamic> j) =>
      Progress(j['p'] as int, j['d'] as int);
}

/// Which categories' scenes belong to a title: movie scene or any episode scene.
bool inScenes(LibraryItem item, Set<String> sceneIds) {
  if (item.movieSceneId != null && sceneIds.contains(item.movieSceneId)) {
    return true;
  }
  return item.episodes.any((e) => sceneIds.contains(e.sceneId));
}

List<LibraryItem> filterLibrary(List<LibraryItem> items,
    {Set<String>? sceneIds, bool favoritesOnly = false, Set<String>? favorites}) {
  return [
    for (final i in items)
      if ((sceneIds == null || inScenes(i, sceneIds)) &&
          (!favoritesOnly || (favorites?.contains(i.key) ?? false)))
        i
  ];
}

/// A title the user started, with its most recently played scene.
class ContinueEntry {
  final LibraryItem item;
  final String sceneId;
  final Progress progress;
  final String? label;
  ContinueEntry(this.item, this.sceneId, this.progress, this.label);
}

/// Titles with an in-progress scene, most recent first. [order] lists scene ids
/// oldest to newest.
List<ContinueEntry> continueWatching(
    List<LibraryItem> items, Map<String, Progress> progress, List<String> order) {
  final out = <ContinueEntry>[];
  final seen = <String>{};
  for (final sid in order.reversed) {
    final p = progress[sid];
    if (p == null || !p.inProgress) continue;
    for (final i in items) {
      Episode? ep;
      for (final e in i.episodes) {
        if (e.sceneId == sid) ep = e;
      }
      if (i.movieSceneId == sid || ep != null) {
        if (seen.add(i.key)) {
          out.add(ContinueEntry(i, sid, p,
              ep == null ? null : 'S${ep.season} E${ep.episode}'));
        }
        break;
      }
    }
  }
  return out;
}

const palettePlayboxId = 'playbox';
const paletteTunaId = 'tuna';

/// Everything stored on the device. Backed by shared_preferences; with no
/// preferences object (tests, early start) it keeps values in memory.
class LocalStore {
  final SharedPreferences? _p;
  final Map<String, Object> _m = {};
  LocalStore([this._p]);
  static Future<LocalStore> open() async =>
      LocalStore(await SharedPreferences.getInstance());

  String? _s(String k) => _p != null ? _p.getString(k) : _m[k] as String?;
  List<String>? _l(String k) =>
      _p != null ? _p.getStringList(k) : (_m[k] as List<String>?);
  Future<void> _put(String k, Object v) async {
    if (_p == null) {
      _m[k] = v;
    } else if (v is String) {
      await _p.setString(k, v);
    } else {
      await _p.setStringList(k, v as List<String>);
    }
  }

  Future<void> _del(String k) async {
    _m.remove(k);
    await _p?.remove(k);
  }

  // Last selected category ('' = All, 'fav' = Favorites).
  String get lastCategory => _s('last_category') ?? '';
  Future<void> setLastCategory(String v) => _put('last_category', v);

  // Favorites, keyed by LibraryItem.key.
  Set<String> get favorites => (_l('favorites') ?? []).toSet();
  bool isFavorite(String key) => favorites.contains(key);
  Future<bool> toggleFavorite(String key) async {
    final f = favorites;
    final on = !f.remove(key);
    if (on) f.add(key);
    await _put('favorites', f.toList());
    return on;
  }

  // Playback positions.
  Map<String, Progress> get progress {
    final raw = _s('progress');
    if (raw == null) return {};
    try {
      return {
        for (final e in (jsonDecode(raw) as Map<String, dynamic>).entries)
          e.key: Progress.fromJson(e.value as Map<String, dynamic>)
      };
    } catch (_) {
      return {};
    }
  }

  List<String> get progressOrder => _l('progress_order') ?? [];

  Future<void> saveProgress(String sceneId, int positionMs, int durationMs) async {
    if (durationMs <= 0) return;
    final m = progress..[sceneId] = Progress(positionMs, durationMs);
    final order = progressOrder
      ..remove(sceneId)
      ..add(sceneId);
    await _put('progress',
        jsonEncode({for (final e in m.entries) e.key: e.value.toJson()}));
    await _put('progress_order', order);
  }

  // Appearance: 'system' | 'dark' | 'light'.
  String get themeMode => _s('theme_mode') ?? 'system';
  Future<void> setThemeMode(String v) => _put('theme_mode', v);
  String get palette => _s('palette') ?? palettePlayboxId;
  Future<void> setPalette(String v) => _put('palette', v);

  // Optional API key (kept in shared_preferences, not the keychain).
  String get apiKey => _s('api_key') ?? '';
  Future<void> setApiKey(String v) => v.isEmpty ? _del('api_key') : _put('api_key', v);

  /// Clears cached data only: positions, last category. Keeps favorites, theme,
  /// server URL and API key.
  Future<void> clearCache() async {
    await _del('progress');
    await _del('progress_order');
    await _del('last_category');
  }
}
