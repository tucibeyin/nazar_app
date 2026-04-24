import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/theme.dart';
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

class NazarApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const NazarApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nazar & Ferahlama',
      debugShowCheckedModeBanner: false,
      theme: nazarTheme,
      home: HomeScreen(cameras: cameras),
    );
  }
}
