class ApiConfig {
  // Derleme zamanında enjekte edilir:
  //   flutter run --dart-define=API_BASE_URL=https://nazar.aracabak.com
  //   flutter run --dart-define=API_KEY=xxx
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://nazar.aracabak.com',
  );

  // Boşsa istek başlığına eklenmez.
  static const String apiKey = String.fromEnvironment('API_KEY', defaultValue: '');

  static String nazarEndpoint(int hashInt) => '$baseUrl/api/v1/nazar/$hashInt';
  static String hatimEndpoint(int index) => '$baseUrl/api/v1/hatim/$index';
  static String get packagesEndpoint => '$baseUrl/api/v1/packages';
  static String packageDetailEndpoint(String id) => '$baseUrl/api/v1/packages/$id';
  static String get esmaulHusnaEndpoint => '$baseUrl/api/v1/esmaul-husna';
  static String prayerTimesEndpoint(double lat, double lng) =>
      '$baseUrl/api/v1/prayer-times?lat=$lat&lng=$lng';
  static String get hatimHalkasiCreateEndpoint =>
      '$baseUrl/api/v1/hatim-halkasi/create';
  static String hatimHalkasiRoomEndpoint(String code) =>
      '$baseUrl/api/v1/hatim-halkasi/$code';
  static String hatimHalkasiJuzEndpoint(String code, int juzNum) =>
      '$baseUrl/api/v1/hatim-halkasi/$code/juz/$juzNum';
  static String audioUrl(String mp3Path) => '$baseUrl$mp3Path';
}
