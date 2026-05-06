import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';

import 'config/theme.dart';
import 'models/esma.dart';
import 'providers/service_providers.dart';
import 'services/notification_service.dart';
import 'screens/backup_screen.dart';
import 'screens/cevsen_screen.dart';
import 'screens/esma_dhikr_screen.dart';
import 'screens/esma_list_screen.dart';
import 'screens/hatim_halkasi_screen.dart';
import 'screens/hatim_screen.dart';
import 'screens/home_screen.dart';
import 'screens/ilkyardim_screen.dart';
import 'screens/ibadet_screen.dart';
import 'screens/kaza_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/tesbihat_screen.dart';
import 'screens/namaz_kilavuzu_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Release build'de tüm debugPrint çağrılarını bastır.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // Bildirim servisini başlat (tz verisi + plugin init, non-blocking).
  await NotificationService().initialize();
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
          path: '/hatim-halkasi',
          builder: (_, __) => const HatimHalkasiScreen(),
        ),
        GoRoute(
          path: '/cevsen',
          builder: (_, __) => const CevsenScreen(),
        ),
        GoRoute(
          path: '/ilkyardim',
          builder: (_, __) => const IlkyardimScreen(),
        ),
        GoRoute(
          path: '/esma-listesi',
          builder: (_, __) => const EsmaListScreen(),
        ),
        GoRoute(
          path: '/esma-dhikr',
          builder: (_, state) => EsmaDhikrScreen(esma: state.extra as Esma),
        ),
        GoRoute(
          path: '/kaza-takip',
          builder: (_, __) => const KazaScreen(),
        ),
        GoRoute(
          path: '/ibadet',
          builder: (_, __) => const IbadetScreen(),
        ),
        GoRoute(
          path: '/backup',
          builder: (_, __) => const BackupScreen(),
        ),
        GoRoute(
          path: '/tesbihat',
          builder: (_, __) => const TesbihatScreen(),
        ),
        GoRoute(
          path: '/namaz-kilavuzu',
          builder: (_, __) => const NamazKilavuzuScreen(),
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
