import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A fake GraphQL endpoint. Records every operation and answers from [handlers],
/// keyed by operation name (the word after query/mutation).
class FakeServer {
  final Map<String, Map<String, dynamic> Function(Map<String, dynamic> vars)> handlers;
  final List<({String op, Map<String, dynamic> vars})> calls = [];
  int status;
  FakeServer(this.handlers, {this.status = 200});

  late final http.Client client = MockClient((req) async {
    if (status != 200) return http.Response('no', status);
    final body = jsonDecode(req.body) as Map<String, dynamic>;
    final q = body['query'] as String;
    final m = RegExp(r'(?:query|mutation)\s+(\w+)').firstMatch(q);
    final op = m?.group(1) ?? '';
    final vars = (body['variables'] as Map).cast<String, dynamic>();
    calls.add((op: op, vars: vars));
    final h = handlers[op];
    if (h == null) {
      return http.Response(
          jsonEncode({'errors': [{'message': 'unknown op $op'}]}), 200);
    }
    try {
      return http.Response(jsonEncode({'data': h(vars)}), 200);
    } on String catch (msg) {
      return http.Response(jsonEncode({'errors': [{'message': msg}]}), 200);
    }
  });

  int count(String op) => calls.where((c) => c.op == op).length;
}

Map<String, dynamic> sourceJson(String hash,
        {String? filePath, String? packTitle, String? qualityNote}) =>
    {
      'title': 'Release $hash',
      'magnet': 'magnet:?xt=urn:btih:$hash',
      'infoHash': hash,
      'sizeBytes': 2147483648,
      'seeds': 42,
      'leeches': 3,
      'uploader': 'u',
      'resolution': 1080,
      'codec': 'x265',
      'filePath': filePath,
      'packTitle': packTitle,
      'qualityNote': qualityNote,
      'alternatives': <dynamic>[],
    };

Map<String, dynamic> torrentJson(String hash,
        {int size = 1000,
        int done = 100,
        bool finished = false,
        bool stalled = false,
        bool paused = false,
        String? sceneId,
        String? corrupt,
        String? filePath}) =>
    {
      'infoHash': hash,
      'name': 'Item $hash',
      'sizeBytes': size,
      'completedBytes': done,
      'peers': 2,
      'downloadRate': 0,
      'hasMetadata': true,
      'stalled': stalled,
      'filePath': filePath,
      'done': finished,
      'videoPath': null,
      'sceneId': sceneId,
      'corruptReason': corrupt,
      'libraryError': null,
      'paused': paused,
      'pauseReason': null,
      'downloadSpeed': 524288,
      'etaSeconds': 90,
      'autoRetryAttempt': 0,
      'autoRetryNote': null,
      'autoDownloaded': false,
    };
