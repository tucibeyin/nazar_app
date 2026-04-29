import 'ayet.dart';
import '../utils/json_ext.dart';

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
        index: json.intOf('index'),
        total: json.intOf('total', 6236),
      );
}
