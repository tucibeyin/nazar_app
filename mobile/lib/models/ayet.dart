import '../utils/json_ext.dart';

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

  factory Ayet.fromJson(Map<String, dynamic> json) {
    final sureIsim = json.strOf('sure_isim');
    return Ayet(
      id: json.intOf('id'),
      sureIsim: sureIsim.length > 200 ? sureIsim.substring(0, 200) : sureIsim,
      arapca: json.strOf('arapca'),
      meal: json.strOf('meal'),
      mp3Url: json.strOf('mp3_url'),
    );
  }

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
