import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/esma.dart';
import 'service_providers.dart';

final esmaulHusnaProvider = FutureProvider<List<Esma>>((ref) async {
  return ref.read(apiServiceProvider).fetchEsmaulHusna();
});
