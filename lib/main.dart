import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';

import 'screens/library_screen.dart';

const pageColor = Color(0xFF101C33);
const primaryColor = Color(0xFF2D8CFF);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const PlayboxApp());
}

class PlayboxApp extends StatelessWidget {
  const PlayboxApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
    ).copyWith(primary: primaryColor, surface: pageColor);
    return MaterialApp(
      title: 'Playbox',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: pageColor,
        appBarTheme: const AppBarTheme(
            backgroundColor: pageColor, surfaceTintColor: Colors.transparent),
        useMaterial3: true,
      ),
      home: const LibraryScreen(),
    );
  }
}
