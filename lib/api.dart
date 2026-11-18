import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const defaultServerUrl = 'http://100.121.45.79:9998';
const _prefKey = 'server_url';
const _apiKeyPref = 'api_key';

const _findCategories = '''query FindCategories(\$filter: FindFilterType, \$category_filter: CategoryFilterType) {
  findCategories(filter: \$filter, category_filter: \$category_filter) {
    count categories { id name parent_category { id } child_categories { id name } } } }''';
const _sceneIdsInCategory = r'''query SceneIdsInCategory($id: ID!) {
  findScenes(scene_filter: {categories: [$id]}, filter: {per_page: -1}) { scenes { id } } }''';
const _saveActivity = r'''mutation SaveActivity($id: ID!, $resume: Float, $dur: Float) {
  sceneSaveActivity(id: $id, resume_time: $resume, playDuration: $dur) }''';

class ApiException implements Exception {
  final String message;
  final bool unreachable;
  /// The server refused the request (profile or permission), as opposed to failing.
  final bool refused;
  ApiException(this.message, {this.unreachable = false, this.refused = false});
  @override
  String toString() => message;
}

bool looksRefused(String m) =>
    RegExp(r'not allowed|forbidden|permission|profile', caseSensitive: false).hasMatch(m);

class Episode {
  final int season;
  final int episode;
  final String sceneId;
  final List<String> subtitleLanguages;
  Episode(this.season, this.episode, this.sceneId, this.subtitleLanguages);
}

class LibraryItem {
  final int id;
  final String name;
  final int? year;
  final String? posterUrl;
  final String? yearRange;
  final List<String> genres;
  final List<Episode> episodes; // empty for movies
  final String? movieSceneId; // set for movies
  LibraryItem({
    required this.id,
    required this.name,
    this.year,
    this.posterUrl,
    this.yearRange,
    this.genres = const [],
    this.episodes = const [],
    this.movieSceneId,
  });
  bool get isMovie => movieSceneId != null;
  String get key => '${isMovie ? 'movie' : 'tv'}:$id';
}

class Category {
  final String id;
  final String name;
  final List<Category> children;
  Category(this.id, this.name, [this.children = const []]);
}

class SeasonInfo {
  final int number;
  final String name;
  final int episodeCount;
  SeasonInfo(this.number, this.name, this.episodeCount);
}

class ShowInfo {
  final String name;
  final String? overview;
  final String? backdropUrl;
  final String? yearRange;
  final List<SeasonInfo> seasons;
  ShowInfo(this.name, this.overview, this.backdropUrl, this.yearRange, this.seasons);
}

class EpisodeInfo {
  final int number;
  final String name;
  final String? airDate;
  final String? stillUrl;
  final int? runtime;
  EpisodeInfo(this.number, this.name, this.airDate, this.stillUrl, this.runtime);
}

// Field selections copied from the web client's operations.
const _tvLibrary = '''query TvLibrary { tvLibrary { id name year posterURL yearRange genres
  episodes { season episode sceneId subtitleLanguages } } }''';
const _movieLibrary =
    'query MovieLibrary { movieLibrary { id name year posterURL genres sceneId } }';
const _tvShow = r'''query TvShow($id: Int!) { tvShow(id: $id) { id name year yearRange
  overview posterURL backdropURL seasons { number name episodeCount } } }''';
const _tvSeasonEpisodes = r'''query TvSeasonEpisodes($tvId: Int!, $season: Int!) {
  tvSeasonEpisodes(tvId: $tvId, season: $season) { number name airDate overview
  stillURL rating ratingVotes runtime } }''';

class PlayboxApi {
  final String baseUrl;
  final http.Client _client;
  final String? apiKey;
  PlayboxApi(String url, {http.Client? client, this.apiKey})
      : baseUrl = url.trim().replaceAll(RegExp(r'/+$'), ''),
        _client = client ?? http.Client();

  static Future<PlayboxApi> load() async {
    final p = await SharedPreferences.getInstance();
    return PlayboxApi(p.getString(_prefKey) ?? defaultServerUrl,
        apiKey: p.getString(_apiKeyPref));
  }

  static Future<void> saveUrl(String url) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefKey, url.trim());
  }

  String streamUrl(String sceneId) => '$baseUrl/scene/$sceneId/stream';

  Future<Map<String, dynamic>> query(String q, [Map<String, dynamic>? vars]) async {
    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse('$baseUrl/graphql'),
            headers: {
              'Content-Type': 'application/json',
              'X-Playbox-Locked': '0',
              if (apiKey != null && apiKey!.isNotEmpty) 'ApiKey': apiKey!,
            },
            body: jsonEncode({'query': q, 'variables': vars ?? {}}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw ApiException('Cannot reach the server at $baseUrl.', unreachable: true);
    }
    if (res.statusCode == 401) {
      throw ApiException('The server asked for a login (401).');
    }
    if (res.statusCode == 403) {
      throw ApiException('The server refused this request for the current profile.',
          refused: true);
    }
    if (res.statusCode != 200) {
      throw ApiException('Server answered HTTP ${res.statusCode}.');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final errors = body['errors'];
    if (errors is List && errors.isNotEmpty) {
      final msg = '${errors.first['message']}';
      throw ApiException(msg, refused: looksRefused(msg));
    }
    return body['data'] as Map<String, dynamic>;
  }

  /// Cheap connectivity check against /graphql.
  Future<void> test() async {
    await query('{ __typename }');
  }

  Future<List<LibraryItem>> library() async {
    final tv = await query(_tvLibrary);
    final items = <LibraryItem>[];
    for (final s in (tv['tvLibrary'] as List)) {
      items.add(LibraryItem(
        id: s['id'],
        name: s['name'],
        year: s['year'],
        posterUrl: s['posterURL'],
        yearRange: s['yearRange'],
        genres: List<String>.from(s['genres']),
        episodes: [
          for (final e in s['episodes'])
            Episode(e['season'], e['episode'], '${e['sceneId']}',
                List<String>.from(e['subtitleLanguages']))
        ],
      ));
    }
    try {
      final mv = await query(_movieLibrary);
      for (final m in (mv['movieLibrary'] as List)) {
        items.add(LibraryItem(
          id: m['id'],
          name: m['name'],
          year: m['year'],
          posterUrl: m['posterURL'],
          genres: List<String>.from(m['genres']),
          movieSceneId: '${m['sceneId']}',
        ));
      }
    } on ApiException catch (e) {
      if (e.unreachable) rethrow; // movies are optional
    }
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  Future<ShowInfo> show(int id) async {
    final d = (await query(_tvShow, {'id': id}))['tvShow'];
    if (d == null) throw ApiException('Show not found.');
    return ShowInfo(
      d['name'],
      d['overview'],
      d['backdropURL'],
      d['yearRange'],
      [
        for (final s in d['seasons'])
          SeasonInfo(s['number'], s['name'], s['episodeCount'])
      ],
    );
  }

  Future<List<EpisodeInfo>> seasonEpisodes(int tvId, int season) async {
    final d = (await query(_tvSeasonEpisodes, {'tvId': tvId, 'season': season}))
        ['tvSeasonEpisodes'] as List;
    return [
      for (final e in d)
        EpisodeInfo(e['number'], e['name'], e['airDate'], e['stillURL'], e['runtime'])
    ];
  }

  /// Top-level categories (those without a parent), in server order.
  Future<List<Category>> categories() async {
    final d = (await query(_findCategories, {
      'filter': {'per_page': -1, 'sort': 'name'}
    }))['findCategories']['categories'] as List;
    return [
      for (final c in d)
        if (c['parent_category'] == null)
          Category('${c['id']}', '${c['name']}', [
            for (final k in (c['child_categories'] as List? ?? []))
              Category('${k['id']}', '${k['name']}')
          ])
    ];
  }

  /// Scene ids under a category's bound directories.
  Future<Set<String>> sceneIdsInCategory(String id) async {
    final d = (await query(_sceneIdsInCategory, {'id': id}))['findScenes']['scenes'] as List;
    return {for (final s in d) '${s['id']}'};
  }

  /// Best-effort resume sync; failures are swallowed (local store is the source of truth).
  Future<bool> saveActivity(String sceneId, double resumeSeconds, double playSeconds) async {
    try {
      await query(_saveActivity, {'id': sceneId, 'resume': resumeSeconds, 'dur': playSeconds});
      return true;
    } catch (_) {
      return false;
    }
  }
}
