import 'package:material_ui/material_ui.dart';

import 'settings_screen.dart';

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool showSettings;
  const ErrorView(
      {super.key,
      required this.message,
      required this.onRetry,
      this.showSettings = true});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Wrap(spacing: 12, children: [
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
              if (showSettings)
                OutlinedButton(
                  onPressed: () async {
                    await Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    onRetry();
                  },
                  child: const Text('Open settings'),
                ),
            ]),
          ]),
        ),
      );
}

class Poster extends StatelessWidget {
  final String? url;
  const Poster(this.url, {super.key});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
        color: Colors.white10,
        child: const Center(child: Icon(Icons.movie_outlined, size: 36)));
    if (url == null || url!.isEmpty) return placeholder;
    return Image.network(url!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
        loadingBuilder: (c, child, p) => p == null ? child : placeholder);
  }
}
