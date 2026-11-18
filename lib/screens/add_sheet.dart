import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../downloads_api.dart';

const noReleaseMessage =
    'No release matched this episode. It may not be out yet, or nothing passed the quality filters.';

/// Finds the best source for [ctx], shows it with alternatives, and adds the chosen one.
/// Returns true when a download was added.
Future<bool> showAddSheet(BuildContext context, PlayboxApi api, SearchContext ctx,
    {String? label}) async {
  final r = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => AddSheet(api: api, ctx: ctx, label: label),
  );
  return r == true;
}

class AddSheet extends StatefulWidget {
  final PlayboxApi api;
  final SearchContext ctx;
  final String? label;
  const AddSheet({super.key, required this.api, required this.ctx, this.label});
  @override
  State<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<AddSheet> {
  late Future<BestPick?> _pick;
  TorrentSource? _chosen;
  bool _showOthers = false;
  bool _adding = false;
  String? _addError;

  @override
  void initState() {
    super.initState();
    _pick = widget.api.bestTorrent(widget.ctx);
  }

  void _retry() => setState(() {
        _addError = null;
        _chosen = null;
        _pick = widget.api.bestTorrent(widget.ctx);
      });

  Future<void> _add(TorrentSource s) async {
    setState(() {
      _adding = true;
      _addError = null;
    });
    try {
      await widget.api.addTorrent(s, widget.ctx);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _adding = false;
          _addError = e.refused
              ? 'The server refused this download: ${e.message}'
              : e.message;
        });
      }
    }
  }

  Widget _sourceCard(TorrentSource s) => Card(
        color: Colors.white10,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.title, maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Text('${formatBytes(s.sizeBytes)} · ${s.seeds} seeders · ${s.leeches} peers'
                '${s.resolution > 0 ? ' · ${s.resolution}p' : ''}'
                '${s.codec != null && s.codec!.isNotEmpty ? ' · ${s.codec}' : ''}'),
            if (s.qualityNote != null && s.qualityNote!.isNotEmpty)
              Text(s.qualityNote!, style: const TextStyle(color: Colors.amber)),
            if (s.packTitle != null && s.packTitle!.isNotEmpty)
              Text('One file from the pack ${s.packTitle}; only this episode is downloaded.',
                  style: const TextStyle(color: Colors.white70)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: FutureBuilder<BestPick?>(
            future: _pick,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()));
              }
              if (snap.hasError) {
                final e = snap.error;
                final msg = e is ApiException && e.refused
                    ? 'The server refused this search: ${e.message}'
                    : '$e';
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(msg, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _retry, child: const Text('Retry')),
                  ]),
                );
              }
              final pick = snap.data;
              if (pick == null) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text(noReleaseMessage, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _retry, child: const Text('Search again')),
                  ]),
                );
              }
              final chosen = _chosen ?? pick.best;
              return ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Text(widget.label ?? widget.ctx.term,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(identical(chosen, pick.best) ? 'Best source' : 'Selected source',
                      style: const TextStyle(color: Colors.white70)),
                  _sourceCard(chosen),
                  if (_addError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(_addError!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _adding ? null : () => _add(chosen),
                    icon: _adding
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.download),
                    label: const Text('Download'),
                  ),
                  if (pick.alternatives.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(() => _showOthers = !_showOthers),
                      child: const Text('Try another source'),
                    ),
                  if (_showOthers)
                    for (final a in pick.all)
                      if (!identical(a, chosen))
                        InkWell(
                          onTap: () => setState(() {
                            _chosen = a;
                            _showOthers = false;
                          }),
                          child: _sourceCard(a),
                        ),
                ],
              );
            },
          ),
        ),
      );
}
