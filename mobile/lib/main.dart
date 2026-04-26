import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';

import 'config/theme.dart';
import 'providers/service_providers.dart';
import 'screens/hatim_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // runApp immediately — no blocking I/O before first frame.
  // SplashScreen loads cameras in the background while animations play.
  runApp(const ProviderScope(child: NazarApp()));
}

class NazarApp extends ConsumerStatefulWidget {
  const NazarApp({super.key});

  @override
  ConsumerState<NazarApp> createState() => _NazarAppState();
}

class _NazarAppState extends ConsumerState<NazarApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      initialLocation: '/splash',
      debugLogDiagnostics: false,
      routes: [
        GoRoute(
          path: '/splash',
          builder: (_, __) => const SplashScreen(),
        ),
        GoRoute(
          path: '/hatim',
          builder: (_, __) => const HatimScreen(),
        ),
        GoRoute(
          path: '/home',
          pageBuilder: (_, state) {
            final cameras = state.extra as List<CameraDescription>? ?? [];
            return CustomTransitionPage<void>(
              key: state.pageKey,
              child: HomeScreen(cameras: cameras),
              transitionDuration: const Duration(milliseconds: 600),
              reverseTransitionDuration: const Duration(milliseconds: 300),
              transitionsBuilder: (_, animation, __, child) => FadeTransition(
                opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
                child: child,
              ),
            );
          },
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
