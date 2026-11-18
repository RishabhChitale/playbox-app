import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class PlayerScreen extends StatefulWidget {
  final String title;
  final String url;
  const PlayerScreen({super.key, required this.title, required this.url});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player = Player();
  late final VideoController _video = VideoController(_player);
  String? _error;
  bool _showControls = true;
  bool _landscape = false;
  bool _fellBack = false;

  @override
  void initState() {
    super.initState();
    _player.stream.error.listen((e) {
      if (!_fellBack && !widget.url.endsWith('.mp4')) {
        // Direct stream failed: try the server's live remux (MP4/AAC).
        _fellBack = true;
        _player.open(Media('${widget.url}.mp4'));
        return;
      }
      if (mounted) setState(() => _error = e);
    });
    _player.open(Media(widget.url));
  }

  @override
  void dispose() {
    _player.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleLandscape() {
    _landscape = !_landscape;
    SystemChrome.setPreferredOrientations(_landscape
        ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
        : [DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(
        _landscape ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
    setState(() {});
  }

  void _skip(int seconds) {
    final pos = _player.state.position + Duration(seconds: seconds);
    final max = _player.state.duration;
    _player.seek(pos < Duration.zero ? Duration.zero : (pos > max ? max : pos));
  }

  Future<void> _pickSubtitle() async {
    final tracks = _player.state.tracks.subtitle;
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView(children: [
        for (final t in tracks)
          ListTile(
            title: Text(t.id == 'no'
                ? 'Off'
                : t.id == 'auto'
                    ? 'Auto'
                    : [t.title, t.language, t.id]
                        .whereType<String>()
                        .where((s) => s.isNotEmpty)
                        .first),
            onTap: () {
              _player.setSubtitleTrack(t);
              Navigator.pop(ctx);
            },
          ),
      ]),
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(children: [
            Center(
              child: GestureDetector(
                onTap: () => setState(() => _showControls = !_showControls),
                child: Video(controller: _video, controls: NoVideoControls),
              ),
            ),
            if (_error != null)
              Center(
                  child: Container(
                      color: Colors.black87,
                      padding: const EdgeInsets.all(16),
                      child: Text('Playback error: $_error',
                          textAlign: TextAlign.center))),
            if (_showControls) ...[
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Row(children: [
                  IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context)),
                  Expanded(
                      child: Text(widget.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                  IconButton(
                      icon: const Icon(Icons.subtitles), onPressed: _pickSubtitle),
                  IconButton(
                      icon: Icon(_landscape
                          ? Icons.fullscreen_exit
                          : Icons.fullscreen),
                      onPressed: _toggleLandscape),
                ]),
              ),
              Positioned(left: 0, right: 0, bottom: 0, child: _bottomBar()),
            ],
          ]),
        ),
      );

  Widget _bottomBar() => Container(
        color: Colors.black54,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          StreamBuilder<Duration>(
            stream: _player.stream.position,
            builder: (_, pos) => StreamBuilder<Duration>(
              stream: _player.stream.duration,
              builder: (_, dur) {
                final d = dur.data ?? _player.state.duration;
                final p = pos.data ?? _player.state.position;
                final max = d.inMilliseconds.toDouble();
                return Row(children: [
                  Text(_fmt(p)),
                  Expanded(
                    child: Slider(
                      value: p.inMilliseconds.toDouble().clamp(0, max > 0 ? max : 1),
                      max: max > 0 ? max : 1,
                      onChanged: (v) =>
                          _player.seek(Duration(milliseconds: v.round())),
                    ),
                  ),
                  Text(_fmt(d)),
                ]);
              },
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
                iconSize: 32,
                icon: const Icon(Icons.replay_10),
                onPressed: () => _skip(-10)),
            StreamBuilder<bool>(
              stream: _player.stream.playing,
              builder: (_, s) => IconButton(
                iconSize: 48,
                icon: Icon((s.data ?? true) ? Icons.pause_circle : Icons.play_circle),
                onPressed: _player.playOrPause,
              ),
            ),
            IconButton(
                iconSize: 32,
                icon: const Icon(Icons.forward_10),
                onPressed: () => _skip(10)),
          ]),
        ]),
      );
}
