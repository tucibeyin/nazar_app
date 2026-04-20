class ApiConfig {
  static const String baseUrl = 'https://nazar.aracabak.com';

  static String nazarEndpoint(int hashInt) => '$baseUrl/api/nazar/$hashInt';
  static String audioUrl(String mp3Path) => '$baseUrl$mp3Path';
}
