import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class SocialShareService {
  SocialShareService._();

  /// [repaintKey] bir [RepaintBoundary] widget'ının GlobalKey'i olmalı.
  /// Widget ekranda render edilmiş durumdayken çağrılmalıdır.
  static Future<void> shareWidgetAsImage(
    GlobalKey repaintKey, {
    String? text,
    double pixelRatio = 3.0,
  }) async {
    final boundary = repaintKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception('Widget henüz render edilmedi.');
    }

    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('Görsel verisi alınamadı.');

    final Uint8List pngBytes = byteData.buffer.asUint8List();
    final Directory tempDir = await getTemporaryDirectory();
    final File file = File(
      '${tempDir.path}/nazar_share_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(pngBytes);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      text: text,
    );
  }
}
