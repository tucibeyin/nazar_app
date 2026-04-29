extension JsonExt on Map<String, dynamic> {
  int intOf(String key, [int def = 0]) {
    final v = this[key];
    return v is num ? v.toInt() : def;
  }

  String strOf(String key, [String def = '']) {
    final v = this[key];
    return v is String ? v : def;
  }
}
