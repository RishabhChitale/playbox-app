import 'package:material_ui/material_ui.dart';

import '../api.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _ctrl = TextEditingController(text: defaultServerUrl);
  String? _status;
  bool _ok = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    PlayboxApi.load().then((a) => setState(() => _ctrl.text = a.baseUrl));
  }

  Future<void> _test() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await PlayboxApi(_ctrl.text).test();
      setState(() {
        _ok = true;
        _status = 'Connected.';
      });
    } on ApiException catch (e) {
      setState(() {
        _ok = false;
        _status = e.message;
      });
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    await PlayboxApi.saveUrl(_ctrl.text);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              Text(_status!,
                  style: TextStyle(color: _ok ? Colors.greenAccent : Colors.redAccent)),
          ]),
        ),
      );
}
