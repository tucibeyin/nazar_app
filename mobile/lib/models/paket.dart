import 'ayet.dart';
import '../utils/json_ext.dart';

class Paket {
  final String id;
  final String isim;
  final String aciklama;
  final String icon;
  final int ayetSayisi;

  const Paket({
    required this.id,
    required this.isim,
    required this.aciklama,
    required this.icon,
    required this.ayetSayisi,
  });

  factory Paket.fromJson(Map<String, dynamic> json) => Paket(
        id: json.strOf('id'),
        isim: json.strOf('isim'),
        aciklama: json.strOf('aciklama'),
        icon: json.strOf('icon'),
        ayetSayisi: json.intOf('ayet_sayisi'),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'isim': isim,
        'aciklama': aciklama,
        'icon': icon,
        'ayet_sayisi': ayetSayisi,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Paket && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class PaketDetay {
  final String id;
  final String isim;
  final String aciklama;
  final String icon;
  final List<Ayet> ayetler;

  const PaketDetay({
    required this.id,
    required this.isim,
    required this.aciklama,
    required this.icon,
    required this.ayetler,
  });

  factory PaketDetay.fromJson(Map<String, dynamic> json) => PaketDetay(
        id: json.strOf('id'),
        isim: json.strOf('isim'),
        aciklama: json.strOf('aciklama'),
        icon: json.strOf('icon'),
        ayetler: (json['ayetler'] as List<dynamic>? ?? [])
            .map((e) => Ayet.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
