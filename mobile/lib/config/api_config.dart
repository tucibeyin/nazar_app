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
  static String packagesEndpoint() => '$baseUrl/api/v1/packages';
  static String packageDetailEndpoint(String id) => '$baseUrl/api/v1/packages/$id';
  static String esmaulHusnaEndpoint() => '$baseUrl/api/v1/esmaul-husna';
  static String audioUrl(String mp3Path) => '$baseUrl$mp3Path';
}
