import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../app_state.dart';
import '../local_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _ctrl = TextEditingController(text: defaultServerUrl);
  final _key = TextEditingController();
  String? _status;
  bool _ok = false;
  bool _busy = false;
  bool _keyLoaded = false;

  @override
  void initState() {
    super.initState();
    PlayboxApi.load().then((a) {
      if (mounted) setState(() => _ctrl.text = a.baseUrl);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_keyLoaded) {
      _keyLoaded = true;
      _key.text = AppScope.of(context).store.apiKey;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await PlayboxApi(_ctrl.text, apiKey: _key.text.trim()).test();
      if (mounted) {
        setState(() {
          _ok = true;
          _status = 'Connected.';
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _ok = false;
          _status = e.message;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final store = AppScope.of(context).store;
    await PlayboxApi.saveUrl(_ctrl.text);
    await store.setApiKey(_key.text.trim());
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _clear() async {
    final state = AppScope.of(context);
    await state.store.clearCache();
    state.touch();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Cache cleared. Favorites and settings were kept.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'system', label: Text('System')),
            ButtonSegment(value: 'dark', label: Text('Dark')),
            ButtonSegment(value: 'light', label: Text('Light')),
          ],
          selected: {state.store.themeMode},
          onSelectionChanged: (s) async {
            await state.setMode(s.first);
            if (mounted) setState(() {});
          },
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: palettePlayboxId, label: Text('Playbox')),
            ButtonSegment(value: paletteTunaId, label: Text('Tuna & Tide')),
          ],
          selected: {state.store.palette},
          onSelectionChanged: (s) async {
            await state.setPalette(s.first);
            if (mounted) setState(() {});
          },
        ),
        const SizedBox(height: 24),
        Text('Server', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _ctrl,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Server base URL',
            hintText: defaultServerUrl,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _key,
          autocorrect: false,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'API key (optional)',
            helperText:
                'Sent as the ApiKey header. Stored on this device in app preferences, not the keychain.',
            helperMaxLines: 2,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          OutlinedButton(
              onPressed: _busy ? null : _test,
              child: const Text('Test connection')),
          const SizedBox(width: 12),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ]),
        const SizedBox(height: 16),
        if (_busy) const LinearProgressIndicator(),
        if (_status != null)
          Text(_status!, style: TextStyle(color: _ok ? scheme.primary : scheme.error)),
        const SizedBox(height: 24),
        Text('Data', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text(
            'Watch positions and favorites are stored on this device only. '
            'Positions are also sent to the server on a best-effort basis.'),
        const SizedBox(height: 8),
        OutlinedButton.icon(
            icon: const Icon(Icons.cleaning_services_outlined),
            label: const Text('Clear cache'),
            onPressed: _clear),
        const SizedBox(height: 4),
        Text('Clears watch positions and the last category. Keeps favorites, theme, server and key.',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
        const SizedBox(height: 24),
        Text('Playbox $appVersion', style: TextStyle(color: scheme.onSurfaceVariant)),
      ]),
    );
  }
}
