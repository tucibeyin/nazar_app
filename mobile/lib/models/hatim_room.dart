enum JuzDurum { bos, alindi, okundu }

class JuzItem {
  final int juzNum;
  final JuzDurum durum;

  const JuzItem({required this.juzNum, required this.durum});

  factory JuzItem.fromJson(Map<String, dynamic> json) => JuzItem(
        juzNum: (json['juz_num'] as num).toInt(),
        durum: JuzDurum.values.byName(json['durum'] as String),
      );

  JuzItem copyWith({JuzDurum? durum}) =>
      JuzItem(juzNum: juzNum, durum: durum ?? this.durum);
}

class HatimRoom {
  final String code;
  final String createdAt;
  final List<JuzItem> juzler;

  const HatimRoom({
    required this.code,
    required this.createdAt,
    required this.juzler,
  });

  factory HatimRoom.fromJson(Map<String, dynamic> json) => HatimRoom(
        code: json['code'] as String,
        createdAt: json['created_at'] as String,
        juzler: (json['juzler'] as List<dynamic>)
            .map((e) => JuzItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
