class Ayet {
  final int id;
  final String sureIsim;
  final String arapca;
  final String meal;
  final String mp3Url;

  Ayet({
    required this.id,
    required this.sureIsim,
    required this.arapca,
    required this.meal,
    required this.mp3Url,
  });

  factory Ayet.fromJson(Map<String, dynamic> json) => Ayet(
        id: json['id'],
        sureIsim: json['sure_isim'],
        arapca: json['arapca'],
        meal: json['meal'],
        mp3Url: json['mp3_url'],
      );
}
