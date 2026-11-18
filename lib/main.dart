import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';

import 'app_state.dart';
import 'local_store.dart';
import 'screens/home_shell.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final state = AppState(await LocalStore.open());
  runApp(PlayboxApp(state: state));
}

class PlayboxApp extends StatelessWidget {
  final AppState state;
  const PlayboxApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) => AppScope(
        state: state,
        child: ListenableBuilder(
          listenable: state,
          builder: (context, _) => MaterialApp(
            title: 'Playbox',
            debugShowCheckedModeBanner: false,
            themeMode: state.mode,
            theme: buildTheme(state.palette, Brightness.light),
            darkTheme: buildTheme(state.palette, Brightness.dark),
            home: const HomeShell(),
          ),
        ),
      );
}
