import 'ayet.dart';

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
        id: json['id'] as String? ?? '',
        isim: json['isim'] as String? ?? '',
        aciklama: json['aciklama'] as String? ?? '',
        icon: json['icon'] as String? ?? '',
        ayetSayisi: (json['ayet_sayisi'] is num)
            ? (json['ayet_sayisi'] as num).toInt()
            : 0,
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
        id: json['id'] as String? ?? '',
        isim: json['isim'] as String? ?? '',
        aciklama: json['aciklama'] as String? ?? '',
        icon: json['icon'] as String? ?? '',
        ayetler: (json['ayetler'] as List<dynamic>? ?? [])
            .map((e) => Ayet.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
