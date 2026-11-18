import 'package:material_ui/material_ui.dart';

import 'local_store.dart';
import 'theme.dart';

const appVersion = '0.3.0';

/// App-wide settings and local data; rebuilds listeners when appearance changes.
class AppState extends ChangeNotifier {
  final LocalStore store;
  late ThemeMode mode = themeModeFrom(store.themeMode);
  late String palette = store.palette;
  AppState(this.store);

  Future<void> setMode(String m) async {
    await store.setThemeMode(m);
    mode = themeModeFrom(m);
    notifyListeners();
  }

  Future<void> setPalette(String p) async {
    await store.setPalette(p);
    palette = p;
    notifyListeners();
  }

  /// Tells listeners that local data (progress, favorites) changed.
  void touch() => notifyListeners();

  static final _fallback = AppState(LocalStore());
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  /// Falls back to an in-memory state when no scope is mounted (widget tests).
  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()?.notifier ??
      AppState._fallback;
}
