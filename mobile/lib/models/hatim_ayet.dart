import 'ayet.dart';

class HatimAyet {
  final Ayet ayet;
  final int index;
  final int total;

  const HatimAyet({
    required this.ayet,
    required this.index,
    required this.total,
  });

  factory HatimAyet.fromJson(Map<String, dynamic> json) => HatimAyet(
        ayet: Ayet.fromJson(json),
        index: (json['index'] is num) ? (json['index'] as num).toInt() : 0,
        total: (json['total'] is num) ? (json['total'] as num).toInt() : 6236,
      );
}
