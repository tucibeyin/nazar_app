class Esma {
  final int id;
  final String isim;
  final String arapca;
  final String anlam;
  final String fazilet;
  final int ebcedDegeri;

  const Esma({
    required this.id,
    required this.isim,
    required this.arapca,
    required this.anlam,
    required this.fazilet,
    required this.ebcedDegeri,
  });

  factory Esma.fromJson(Map<String, dynamic> json) => Esma(
        id: (json['id'] as num).toInt(),
        isim: json['isim'] as String? ?? '',
        arapca: json['arapca'] as String? ?? '',
        anlam: json['anlam'] as String? ?? '',
        fazilet: json['fazilet'] as String? ?? '',
        ebcedDegeri: (json['ebced_degeri'] as num?)?.toInt() ?? 0,
      );
}
