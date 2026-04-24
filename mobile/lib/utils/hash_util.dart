import 'dart:typed_data';

import 'package:crypto/crypto.dart';

abstract final class HashUtil {
  /// SHA-256 hash'inden 8 baytlık big-endian int üretir.
  /// Negatif çıkmasını önlemek için abs() uygulanır.
  static int fromBytes(Uint8List bytes) {
    final digest = sha256.convert(bytes);
    final first8 = Uint8List.fromList(digest.bytes.sublist(0, 8));
    return ByteData.sublistView(first8).getInt64(0, Endian.big).abs();
  }
}
