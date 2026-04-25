import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'config/theme.dart';
import 'providers/service_providers.dart';
import 'screens/home_screen.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(
    ProviderScope(
      child: NazarApp(cameras: cameras),
    ),
  );
}

class NazarApp extends ConsumerStatefulWidget {
  final List<CameraDescription> cameras;
  const NazarApp({super.key, required this.cameras});

  @override
  ConsumerState<NazarApp> createState() => _NazarAppState();
}

class _NazarAppState extends ConsumerState<NazarApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      debugLogDiagnostics: false,
      routes: [
        GoRoute(
          path: '/',
          name: 'home',
          builder: (_, __) => HomeScreen(cameras: widget.cameras),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    return MaterialApp.router(
      title: 'Nazar & Ferahlama',
      debugShowCheckedModeBanner: false,
      theme: nazarTheme,
      darkTheme: nazarDarkTheme,
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}
