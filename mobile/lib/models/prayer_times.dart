import 'dart:math' as math;

class PrayerTimesData {
  final double lat;
  final double lng;
  final String imsak;
  final String gunes;
  final String ogle;
  final String ikindi;
  final String aksam;
  final String yatsi;

  const PrayerTimesData({
    required this.lat,
    required this.lng,
    required this.imsak,
    required this.gunes,
    required this.ogle,
    required this.ikindi,
    required this.aksam,
    required this.yatsi,
  });

  factory PrayerTimesData.fromJson(
    Map<String, dynamic> json, {
    required double lat,
    required double lng,
  }) =>
      PrayerTimesData(
        lat: lat,
        lng: lng,
        imsak: json['imsak'] as String,
        gunes: json['gunes'] as String,
        ogle: json['ogle'] as String,
        ikindi: json['ikindi'] as String,
        aksam: json['aksam'] as String,
        yatsi: json['yatsi'] as String,
      );

  List<(String, DateTime)> get vakitler => [
        ('İmsak', _parse(imsak)),
        ('Güneş', _parse(gunes)),
        ('Öğle', _parse(ogle)),
        ('İkindi', _parse(ikindi)),
        ('Akşam', _parse(aksam)),
        ('Yatsı', _parse(yatsi)),
      ];

  DateTime _parse(String t) {
    final p = t.split(':');
    final d = DateTime.now();
    return DateTime(d.year, d.month, d.day, int.parse(p[0]), int.parse(p[1]));
  }

  (String, DateTime)? nextVakit(DateTime now) {
    for (final (name, time) in vakitler) {
      if (time.isAfter(now)) return (name, time);
    }
    return null;
  }

  String? currentVakit(DateTime now) {
    String? current;
    for (final (name, time) in vakitler) {
      if (!time.isAfter(now)) current = name;
    }
    return current;
  }

  // Qibla direction in degrees from North (0–360).
  double get qibla {
    const kLat = 21.4225 * math.pi / 180;
    const kLng = 39.8262;
    final phi = lat * math.pi / 180;
    final dL = (kLng - lng) * math.pi / 180;
    final y = math.sin(dL);
    final x = math.cos(phi) * math.tan(kLat) - math.sin(phi) * math.cos(dL);
    final angle = math.atan2(y, x) * 180 / math.pi;
    return (angle + 360) % 360;
  }

  // Haversine distance to Mecca in km.
  double get distanceToMecca {
    const r = 6371.0;
    const kLat = 21.4225;
    const kLng = 39.8262;
    final phi1 = lat * math.pi / 180;
    const phi2 = kLat * math.pi / 180;
    final dPhi = (kLat - lat) * math.pi / 180;
    final dLng = (kLng - lng) * math.pi / 180;
    final a = math.pow(math.sin(dPhi / 2), 2) +
        math.cos(phi1) * math.cos(phi2) * math.pow(math.sin(dLng / 2), 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
