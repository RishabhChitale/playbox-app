import 'package:material_ui/material_ui.dart';

import 'local_store.dart';

/// Extra style flags the palettes carry beyond ColorScheme.
class PlayboxStyle extends ThemeExtension<PlayboxStyle> {
  final bool hardShadow;
  final Color ink;
  final Color card;
  const PlayboxStyle({required this.hardShadow, required this.ink, required this.card});

  @override
  PlayboxStyle copyWith({bool? hardShadow, Color? ink, Color? card}) => PlayboxStyle(
      hardShadow: hardShadow ?? this.hardShadow,
      ink: ink ?? this.ink,
      card: card ?? this.card);

  @override
  PlayboxStyle lerp(ThemeExtension<PlayboxStyle>? other, double t) => this;
}

const pageColor = Color(0xFF101C33);
const primaryColor = Color(0xFF2D8CFF);

ThemeMode themeModeFrom(String s) =>
    s == 'dark' ? ThemeMode.dark : s == 'light' ? ThemeMode.light : ThemeMode.system;

/// Builds the ThemeData for a palette id and brightness.
ThemeData buildTheme(String palette, Brightness b) {
  final dark = b == Brightness.dark;
  late Color page, primary, card, ink, onPrimary, nav;
  var hard = false;
  if (palette == paletteTunaId) {
    hard = true;
    ink = const Color(0xFF1F3A5F);
    if (dark) {
      page = const Color(0xFF16212F);
      primary = const Color(0xFFF2B66D);
      onPrimary = const Color(0xFF16212F);
      card = const Color(0xFF223248);
      nav = const Color(0xFF1F3A5F);
      ink = const Color(0xFFEFE6CF);
    } else {
      page = const Color(0xFFF6EFDC);
      primary = const Color(0xFF1F3A5F);
      onPrimary = const Color(0xFFF6EFDC);
      card = const Color(0xFFFFFAEB);
      nav = const Color(0xFF1F3A5F);
    }
  } else {
    ink = dark ? Colors.white : const Color(0xFF0B1B33);
    if (dark) {
      page = pageColor;
      primary = primaryColor;
      onPrimary = Colors.white;
      card = const Color(0xFF1A2B4C);
      nav = pageColor;
    } else {
      page = const Color(0xFFF3F7FD);
      primary = const Color(0xFF1B6FD8);
      onPrimary = Colors.white;
      card = Colors.white;
      nav = page;
    }
  }
  final base = ColorScheme.fromSeed(seedColor: primary, brightness: b);
  final scheme = base.copyWith(
    primary: primary,
    onPrimary: onPrimary,
    surface: page,
    onSurface: dark ? const Color(0xFFEAF0FA) : (palette == paletteTunaId ? ink : const Color(0xFF0B1B33)),
    onSurfaceVariant: dark ? const Color(0xFFB4C0D6) : const Color(0xFF4A5670),
    surfaceContainerHighest: card,
    surfaceContainerHigh: card,
    surfaceContainer: card,
    outlineVariant: dark ? const Color(0x33FFFFFF) : const Color(0x33000000),
  );
  final tunaLight = palette == paletteTunaId && !dark;
  final appBarBg = tunaLight || (palette == paletteTunaId) ? nav : page;
  final appBarFg = (palette == paletteTunaId) ? const Color(0xFFF6EFDC) : scheme.onSurface;
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: page,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      backgroundColor: appBarBg,
      foregroundColor: appBarFg,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: palette == paletteTunaId ? nav : card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: palette == paletteTunaId
          ? const Color(0xFFF2B66D)
          : primary.withValues(alpha: 0.25),
      iconTheme: WidgetStateProperty.resolveWith((s) {
        final sel = s.contains(WidgetState.selected);
        if (palette == paletteTunaId) {
          return IconThemeData(color: sel ? const Color(0xFF1F3A5F) : const Color(0xFFF6EFDC));
        }
        return IconThemeData(color: sel ? scheme.onSurface : scheme.onSurfaceVariant);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
          fontSize: 12,
          color: palette == paletteTunaId ? const Color(0xFFF6EFDC) : scheme.onSurface)),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(hard ? 6 : 12),
        side: hard ? BorderSide(color: ink, width: 1.5) : BorderSide.none,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: card,
      selectedColor: primary,
      labelStyle: TextStyle(color: scheme.onSurface),
      secondaryLabelStyle: TextStyle(color: onPrimary),
      checkmarkColor: onPrimary,
      side: BorderSide(color: hard ? ink : scheme.outlineVariant),
    ),
    extensions: [PlayboxStyle(hardShadow: hard, ink: ink, card: card)],
  );
}
