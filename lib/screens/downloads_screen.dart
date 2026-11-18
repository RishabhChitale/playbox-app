import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../downloads_api.dart';
import 'player_screen.dart';
import 'widgets.dart';

const removeDialogText =
    'This stops the download and removes it from the list. Files that were already '
    'downloaded are KEPT on disk; nothing is deleted.';

/// Lists downloads and polls the server every [pollInterval] while [active] is true.
class DownloadsScreen extends StatefulWidget {
  final PlayboxApi api;
  final bool active;
  final Duration pollInterval;
  const DownloadsScreen(
      {super.key,
      required this.api,
      this.active = true,
      this.pollInterval = const Duration(seconds: 3)});
  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<Download>? _items;
  Object? _error;
  bool _loading = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(DownloadsScreen old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active || old.api != widget.api) _syncTimer();
  }

  void _syncTimer() {
    _timer?.cancel();
    _timer = null;
    if (!widget.active) return;
    _refresh();
    _timer = Timer.periodic(widget.pollInterval, (_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_loading) return;
    _loading = true;
    try {
      final l = await widget.api.downloads();
      if (mounted) {
        setState(() {
          _items = l;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _act(Future<void> Function() f) async {
    try {
      await f();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.refused
                ? 'The server refused this action: ${e.message}'
                : e.message)));
      }
    }
    await _refresh();
  }

  Future<void> _confirmRemove(Download d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remove from downloads?'),
        content: Text('${d.name}\n\n$removeDialogText'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true) await _act(() => widget.api.removeDownload(d));
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    final items = _items;
    if (items == null && _error == null) {
      body = const SkeletonList(count: 4);
    } else if (items == null) {
      final e = _error;
      body = ErrorView(
          message: e is ApiException && e.refused
              ? 'The server refused this request: ${e.message}'
              : '$e',
          onRetry: _refresh,
          showSettings: e is ApiException && e.unreachable);
    } else if (items.isEmpty) {
      body = const EmptyView(
          message: 'No downloads yet.',
          hint: 'Add a movie or episode and it shows up here.',
          icon: Icons.download_outlined);
    } else {
      body = ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length + (_error != null ? 1 : 0),
        itemBuilder: (_, i) {
          if (_error != null && i == 0) {
            return ListTile(
              leading: const Icon(Icons.cloud_off),
              title: const Text('Could not refresh. Showing the last known state.'),
              trailing: TextButton(onPressed: _refresh, child: const Text('Retry')),
            );
          }
          final d = items[i - (_error != null ? 1 : 0)];
          return DownloadTile(
            key: ValueKey(d.key),
            d: d,
            api: widget.api,
            onPause: () => _act(() => widget.api.pauseDownload(d)),
            onResume: () => _act(() => widget.api.resumeDownload(d)),
            onRemove: () => _confirmRemove(d),
          );
        },
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      body: RefreshIndicator(onRefresh: _refresh, child: body),
    );
  }
}

class DownloadTile extends StatelessWidget {
  final Download d;
  final PlayboxApi api;
  final VoidCallback onPause, onResume, onRemove;
  const DownloadTile(
      {super.key,
      required this.d,
      required this.api,
      required this.onPause,
      required this.onResume,
      required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lines = <Widget>[];
    Color? note;
    String? status;
    if (!d.hasMetadata) {
      status = 'Fetching file list';
    } else if (d.corruptReason != null) {
      status = "This file downloaded, but it's corrupt and won't play: ${d.corruptReason}.";
      note = scheme.error;
    } else if (d.libraryError != null) {
      status = "Downloaded, but it couldn't be added to your library: ${d.libraryError}";
      note = scheme.error;
    } else if (d.done && d.sceneId == null) {
      status = 'Adding to your library...';
    } else if (d.done) {
      status = 'Ready to play';
    } else if (d.paused) {
      status = d.pauseReason != null && d.pauseReason!.isNotEmpty
          ? 'Paused: ${d.pauseReason}'
          : 'Paused';
    } else if (d.stalled) {
      status = 'No data has arrived for a few minutes; the seeders may be gone.';
      note = scheme.tertiary;
    } else {
      final speed = formatSpeed(d.downloadSpeed ?? 0);
      status = '$speed · ${formatEta(d.etaSeconds)} · ${d.peers} peers';
    }
    lines.add(Text(d.name, maxLines: 2, overflow: TextOverflow.ellipsis));
    if (!d.done && d.hasMetadata) {
      lines.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: LinearProgressIndicator(value: d.fraction),
      ));
      lines.add(Text(
          '${formatBytes(d.completedBytes)} of ${formatBytes(d.sizeBytes)} '
          '(${(d.fraction * 100).round()}%)',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)));
    }
    lines.add(Text(status, style: TextStyle(color: note ?? scheme.onSurface, fontSize: 13)));
    if (d.autoRetryNote != null && d.autoRetryNote!.isNotEmpty) {
      lines.add(Text(d.autoRetryNote!,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)));
    }
    final canPlay = d.done && d.sceneId != null && d.corruptReason == null;
    return Card(
      color: scheme.surfaceContainerHighest,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 6),
        child: Row(children: [
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: lines)),
          if (canPlay)
            IconButton(
              tooltip: 'Play',
              icon: const Icon(Icons.play_arrow),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        PlayerScreen(
                        title: d.name,
                        url: api.streamUrl(d.sceneId!),
                        sceneId: d.sceneId,
                        api: api)),
              ),
            )
          else if (!d.done && d.paused)
            IconButton(
                tooltip: 'Resume',
                icon: const Icon(Icons.play_circle_outline),
                onPressed: onResume)
          else if (!d.done)
            IconButton(
                tooltip: 'Pause',
                icon: const Icon(Icons.pause_circle_outline),
                onPressed: onPause),
          IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.delete_outline),
              onPressed: onRemove),
        ]),
      ),
    );
  }
}
