import 'api.dart';

// Download-related operations: the same documents and field selections as the web client
// (ui/v2.5/graphql/queries/torrent.graphql and mutations/torrent.graphql).
const _sourceFields = '''title magnet infoHash sizeBytes seeds leeches uploader resolution
  codec uploadedAt season episode runtimeMinutes bitrateMbps candidates filePath
  packTitle qualityNote''';
const _bestTorrent = '''query BestTorrent(\$term: String!, \$mediaType: String, \$tmdbId: Int,
  \$airDate: String) { bestTorrent(term: \$term, mediaType: \$mediaType, tmdbId: \$tmdbId,
  airDate: \$airDate) { $_sourceFields alternatives { $_sourceFields } } }''';
const _torrents = '''query Torrents { torrents { infoHash name sizeBytes completedBytes peers
  downloadRate hasMetadata stalled filePath done videoPath sceneId corruptReason libraryError
  paused pauseReason downloadSpeed etaSeconds autoRetryAttempt autoRetryNote
  autoDownloaded } }''';
const _tvSearch =
    r'query TvSearch($query: String!) { tvSearch(query: $query) { id name year overview posterURL } }';
const _movieSearch =
    r'query MovieSearch($query: String!) { movieSearch(query: $query) { id title year overview posterURL } }';
const _addTorrent =
    r'''mutation AddTorrent($magnet: String!, $filePath: String, $search: TorrentSearchInput,
  $replaces: TorrentRefInput) { addTorrent(magnet: $magnet, filePath: $filePath,
  search: $search, replaces: $replaces) }''';
const _removeTorrent =
    r'mutation RemoveTorrent($infoHash: String!, $filePath: String) { removeTorrent(infoHash: $infoHash, filePath: $filePath) }';
const _pauseTorrent =
    r'mutation PauseTorrent($infoHash: String!) { pauseTorrent(infoHash: $infoHash) }';
const _resumeTorrent =
    r'mutation ResumeTorrent($infoHash: String!) { resumeTorrent(infoHash: $infoHash) }';

class SearchResult {
  final int id;
  final String title;
  final int? year;
  final String? overview;
  final String? posterUrl;
  final bool isMovie;
  SearchResult(this.id, this.title, this.year, this.overview, this.posterUrl,
      {required this.isMovie});
}

class TorrentSource {
  final String title;
  final String magnet;
  final String infoHash;
  final int sizeBytes;
  final int seeds;
  final int leeches;
  final String? uploader;
  final int resolution;
  final String? codec;
  final String? filePath;
  final String? packTitle;
  final String? qualityNote;
  TorrentSource({
    required this.title,
    required this.magnet,
    required this.infoHash,
    required this.sizeBytes,
    required this.seeds,
    required this.leeches,
    this.uploader,
    this.resolution = 0,
    this.codec,
    this.filePath,
    this.packTitle,
    this.qualityNote,
  });
  factory TorrentSource.fromJson(Map<String, dynamic> j) => TorrentSource(
        title: '${j['title']}',
        magnet: '${j['magnet']}',
        infoHash: '${j['infoHash']}',
        sizeBytes: (j['sizeBytes'] as num?)?.toInt() ?? 0,
        seeds: (j['seeds'] as num?)?.toInt() ?? 0,
        leeches: (j['leeches'] as num?)?.toInt() ?? 0,
        uploader: j['uploader'],
        resolution: (j['resolution'] as num?)?.toInt() ?? 0,
        codec: j['codec'],
        filePath: j['filePath'],
        packTitle: j['packTitle'],
        qualityNote: j['qualityNote'],
      );
}

/// The best source for a title plus the other sources to fall back on.
class BestPick {
  final TorrentSource best;
  final List<TorrentSource> alternatives;
  BestPick(this.best, this.alternatives);
  List<TorrentSource> get all => [best, ...alternatives];
}

/// What a download is for; sent back with addTorrent (TorrentSearchInput).
class SearchContext {
  final String term;
  final String mediaType; // "movie" | "tv"
  final int tmdbId;
  final String? airDate;
  SearchContext(this.term, this.mediaType, this.tmdbId, [this.airDate]);
  Map<String, dynamic> toJson() => {
        'term': term,
        'mediaType': mediaType,
        'tmdbId': tmdbId,
        if (airDate != null) 'airDate': airDate,
      };
}

class Download {
  final String infoHash;
  final String name;
  final int sizeBytes;
  final int completedBytes;
  final int peers;
  final bool hasMetadata;
  final bool stalled;
  final String? filePath;
  final bool done;
  final String? sceneId;
  final String? corruptReason;
  final String? libraryError;
  final bool paused;
  final String? pauseReason;
  final int? downloadSpeed;
  final int? etaSeconds;
  final String? autoRetryNote;
  Download({
    required this.infoHash,
    required this.name,
    required this.sizeBytes,
    required this.completedBytes,
    required this.peers,
    required this.hasMetadata,
    required this.stalled,
    this.filePath,
    required this.done,
    this.sceneId,
    this.corruptReason,
    this.libraryError,
    required this.paused,
    this.pauseReason,
    this.downloadSpeed,
    this.etaSeconds,
    this.autoRetryNote,
  });
  factory Download.fromJson(Map<String, dynamic> j) => Download(
        infoHash: '${j['infoHash']}',
        name: '${j['name']}',
        sizeBytes: (j['sizeBytes'] as num?)?.toInt() ?? 0,
        completedBytes: (j['completedBytes'] as num?)?.toInt() ?? 0,
        peers: (j['peers'] as num?)?.toInt() ?? 0,
        hasMetadata: j['hasMetadata'] == true,
        stalled: j['stalled'] == true,
        filePath: j['filePath'],
        done: j['done'] == true,
        sceneId: j['sceneId'] == null ? null : '${j['sceneId']}',
        corruptReason: j['corruptReason'],
        libraryError: j['libraryError'],
        paused: j['paused'] == true,
        pauseReason: j['pauseReason'],
        downloadSpeed: (j['downloadSpeed'] as num?)?.toInt(),
        etaSeconds: (j['etaSeconds'] as num?)?.toInt(),
        autoRetryNote: j['autoRetryNote'],
      );
  double get fraction =>
      sizeBytes > 0 ? (completedBytes / sizeBytes).clamp(0.0, 1.0) : 0.0;
  String get key => '$infoHash/${filePath ?? ''}';
}

String formatSpeed(int bytesPerSecond) => bytesPerSecond >= 1024 * 1024
    ? '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s'
    : '${(bytesPerSecond / 1024).round()} KB/s';

String formatEta(int? seconds) {
  if (seconds == null) return 'Calculating...';
  if (seconds < 60) return '$seconds sec left';
  final min = (seconds / 60).round();
  if (min < 60) return '$min min left';
  final h = seconds ~/ 3600;
  if (h >= 48) return '${(h / 24).round()} days left';
  return '$h h ${((seconds % 3600) / 60).round()} min left';
}

String formatBytes(int bytes) {
  final gib = bytes / (1024 * 1024 * 1024);
  return gib >= 1
      ? '${gib.toStringAsFixed(2)} GiB'
      : '${(bytes / (1024 * 1024)).round()} MiB';
}

extension PlayboxDownloads on PlayboxApi {
  /// Movies first, then shows, like the web search.
  Future<List<SearchResult>> searchTitles(String q) async {
    final mv = await query(_movieSearch, {'query': q});
    final tv = await query(_tvSearch, {'query': q});
    return [
      for (final m in mv['movieSearch'] as List)
        SearchResult(m['id'], m['title'], m['year'], m['overview'], m['posterURL'],
            isMovie: true),
      for (final s in tv['tvSearch'] as List)
        SearchResult(s['id'], s['name'], s['year'], s['overview'], s['posterURL'],
            isMovie: false),
    ];
  }

  /// Null when no release matched.
  Future<BestPick?> bestTorrent(SearchContext c) async {
    final d = (await query(_bestTorrent, {
      'term': c.term,
      'mediaType': c.mediaType,
      'tmdbId': c.tmdbId,
      'airDate': c.airDate,
    }))['bestTorrent'];
    if (d == null) return null;
    return BestPick(TorrentSource.fromJson(d), [
      for (final a in (d['alternatives'] as List? ?? []))
        TorrentSource.fromJson(a)
    ]);
  }

  Future<void> addTorrent(TorrentSource s, SearchContext c,
      {Download? replaces}) async {
    await query(_addTorrent, {
      'magnet': s.magnet,
      'filePath': s.filePath,
      'search': c.toJson(),
      if (replaces != null)
        'replaces': {'infoHash': replaces.infoHash, 'filePath': replaces.filePath},
    });
  }

  Future<List<Download>> downloads() async {
    final d = (await query(_torrents))['torrents'] as List;
    return [for (final t in d) Download.fromJson(t)];
  }

  Future<void> removeDownload(Download d) =>
      query(_removeTorrent, {'infoHash': d.infoHash, 'filePath': d.filePath});
  Future<void> pauseDownload(Download d) =>
      query(_pauseTorrent, {'infoHash': d.infoHash});
  Future<void> resumeDownload(Download d) =>
      query(_resumeTorrent, {'infoHash': d.infoHash});
}
