import 'memory.dart';

/// One filter on the list. A blank condition (nothing chosen or
/// typed yet) is skipped, so it matches everyone.
abstract interface class FilterCondition {
  bool get isBlank;

  bool matches(Memory memory);
}
