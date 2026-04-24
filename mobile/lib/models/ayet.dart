class Ayet {
  final int id;
  final String sureIsim;
  final String arapca;
  final String meal;
  final String mp3Url;

  const Ayet({
    required this.id,
    required this.sureIsim,
    required this.arapca,
    required this.meal,
    required this.mp3Url,
  });

  factory Ayet.fromJson(Map<String, dynamic> json) => Ayet(
        id: (json['id'] is num) ? (json['id'] as num).toInt() : 0,
        sureIsim: (json['sure_isim'] is String) ? (json['sure_isim'] as String).substring(0, _clamp(json['sure_isim'] as String)) : '',
        arapca: (json['arapca'] is String) ? json['arapca'] as String : '',
        meal: (json['meal'] is String) ? json['meal'] as String : '',
        mp3Url: (json['mp3_url'] is String) ? json['mp3_url'] as String : '',
      );

  static int _clamp(String s) => s.length > 200 ? 200 : s.length;

  Ayet copyWith({
    int? id,
    String? sureIsim,
    String? arapca,
    String? meal,
    String? mp3Url,
  }) =>
      Ayet(
        id: id ?? this.id,
        sureIsim: sureIsim ?? this.sureIsim,
        arapca: arapca ?? this.arapca,
        meal: meal ?? this.meal,
        mp3Url: mp3Url ?? this.mp3Url,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Ayet && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Ayet(id: $id, sureIsim: $sureIsim)';
}
