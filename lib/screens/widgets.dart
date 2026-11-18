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
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        child: const Center(child: Icon(Icons.movie_outlined, size: 36)));
    if (url == null || url!.isEmpty) return placeholder;
    return Image.network(url!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
        loadingBuilder: (c, child, p) => p == null ? child : placeholder);
  }
}

/// A pulsing grey block used while a list loads.
class Skeleton extends StatefulWidget {
  final double? width, height;
  final double radius;
  const Skeleton({super.key, this.width, this.height, this.radius = 8});
  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: base.withValues(alpha: 0.06 + 0.08 * _c.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Placeholder poster grid shown while the library loads.
class SkeletonGrid extends StatelessWidget {
  const SkeletonGrid({super.key});
  @override
  Widget build(BuildContext context) => GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 170,
            childAspectRatio: 0.55,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10),
        itemCount: 12,
        itemBuilder: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Expanded(child: Skeleton(width: double.infinity)),
              SizedBox(height: 6),
              Skeleton(height: 12, width: 100),
            ]),
      );
}

/// Placeholder rows shown while a list of rows loads.
class SkeletonList extends StatelessWidget {
  final int count;
  const SkeletonList({super.key, this.count = 5});
  @override
  Widget build(BuildContext context) => ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: count,
        itemBuilder: (_, _) => const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Skeleton(height: 64),
        ),
      );
}

/// A friendly message for an empty list, scrollable so pull-to-refresh works.
class EmptyView extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? hint;
  const EmptyView(
      {super.key, required this.message, this.hint, this.icon = Icons.inbox_outlined});
  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
      const SizedBox(height: 120),
      Icon(icon, size: 48, color: muted),
      const SizedBox(height: 12),
      Text(message, textAlign: TextAlign.center),
      if (hint != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(hint!, textAlign: TextAlign.center, style: TextStyle(color: muted)),
        ),
    ]);
  }
}
