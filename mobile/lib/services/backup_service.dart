import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackupService {
  BackupService._();

  static const int _kVersion = 1;
  static const String _kFileName = 'nazar_yedek.json';

  // ── Export ────────────────────────────────────────────────────────────────

  static Future<void> exportData() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> dataMap = {};

    for (final key in prefs.getKeys()) {
      final entry = _detectEntry(prefs, key);
      if (entry != null) dataMap[key] = entry;
    }

    final payload = jsonEncode({
      'version': _kVersion,
      'app': 'nazar',
      'exported_at': DateTime.now().toIso8601String(),
      'data': dataMap,
    });

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$_kFileName');
    await file.writeAsString(payload, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'Nazar & Ferahlama — Veri Yedeği',
    );
  }

  // ── Import ────────────────────────────────────────────────────────────────

  /// Geri yüklenen anahtar sayısını döner; 0 ise kullanıcı iptal etti.
  static Future<int> importData() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return 0;

    final path = result.files.single.path;
    if (path == null) throw Exception('Dosya yolu alınamadı.');

    final raw = await File(path).readAsString();
    late final Map<String, dynamic> payload;
    try {
      payload = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Dosya geçerli bir yedek değil.');
    }

    final version = payload['version'];
    if (version is! int || version > _kVersion) {
      throw Exception(
          'Bu yedek daha yeni bir uygulama sürümüyle oluşturulmuş.\n'
          'Uygulamayı güncelleyip tekrar dene.');
    }

    if (payload['app'] != 'nazar') {
      throw Exception('Bu dosya Nazar & Ferahlama yedeği değil.');
    }

    final rawData = payload['data'];
    if (rawData is! Map) throw Exception('Yedek dosyası bozuk.');

    final prefs = await SharedPreferences.getInstance();
    int restored = 0;

    for (final entry in rawData.entries) {
      final key = entry.key as String;
      final meta = entry.value;
      if (meta is! Map) continue;

      final type = meta['type'] as String?;
      final value = meta['value'];
      if (type == null || value == null) continue;

      try {
        switch (type) {
          case 'bool':
            await prefs.setBool(key, value as bool);
          case 'int':
            await prefs.setInt(key, (value as num).toInt());
          case 'double':
            await prefs.setDouble(key, (value as num).toDouble());
          case 'String':
            await prefs.setString(key, value as String);
          case 'StringList':
            await prefs.setStringList(key, List<String>.from(value as List));
        }
        restored++;
      } catch (_) {
        // Tek bir key hata verirse atla; gerisini yükle.
      }
    }

    return restored;
  }

  // ── Yardımcı: tip algılama ────────────────────────────────────────────────

  static Map<String, dynamic>? _detectEntry(
      SharedPreferences prefs, String key) {
    // bool → int → double → StringList → String sırasıyla denenirse
    // hiçbir tip çakışması olmaz (SharedPreferences tipleri ayrık saklar).
    final b = prefs.getBool(key);
    if (b != null) return {'type': 'bool', 'value': b};

    final i = prefs.getInt(key);
    if (i != null) return {'type': 'int', 'value': i};

    final d = prefs.getDouble(key);
    if (d != null) return {'type': 'double', 'value': d};

    final sl = prefs.getStringList(key);
    if (sl != null) return {'type': 'StringList', 'value': sl};

    final s = prefs.getString(key);
    if (s != null) return {'type': 'String', 'value': s};

    return null;
  }
}
