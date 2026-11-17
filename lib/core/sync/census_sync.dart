import 'package:flutter/foundation.dart';

/// Shared signal so Census and Today refresh after chart mutations
/// (fact review, summary generate, plan save, note review) without a
/// manual pull-to-refresh.
class CensusSync {
  CensusSync();

  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  void markDirty() => revision.value++;

  void dispose() => revision.dispose();
}
