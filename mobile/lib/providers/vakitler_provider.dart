import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/prayer_times.dart';
import '../services/api_service.dart';
import 'service_providers.dart';

final vakitlerProvider = FutureProvider<PrayerTimesData>((ref) async {
  // 1) İzin durumunu kontrol et
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
    throw const ApiException(
      'Konum izni verilmedi. Ayarlardan konum iznini açabilirsiniz.',
      statusCode: 403,
    );
  }

  // 2) Konum servisinin açık olup olmadığını kontrol et
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw const ApiException('Konum servisi kapalı. Lütfen cihaz ayarlarından açın.', statusCode: 503);
  }

  // 3) Güncel konumu al (medium accuracy yeterli)
  final pos = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
  ).timeout(
    const Duration(seconds: 15),
    onTimeout: () => throw const ApiException('Konum alınamadı. GPS sinyali zayıf olabilir.'),
  );

  // 4) Backend'den namaz vakitlerini çek
  return ref.read(apiServiceProvider).fetchPrayerTimes(pos.latitude, pos.longitude);
});
