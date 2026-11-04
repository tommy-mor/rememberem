import 'memory.dart';

/// How many faces and details Fred remembers: those with at least
/// [threshold] points. Counted from the active people only.
class RememberedCount {
  const RememberedCount(this.faces, this.details);

  /// [active] is the list `all()` returns; nothing is changed.
  factory RememberedCount.of(
    List<Memory> active, {
    int threshold = defaultThreshold,
  }) =>
      RememberedCount(
        active.where((m) => isRemembered(m.points, threshold)).length,
        [
          for (final m in active)
            for (final d in m.details)
              if (isRemembered(d.points, threshold) && d.text.trim().isNotEmpty)
                d,
        ].length,
      );

  static const int defaultThreshold = 5;

  /// The one test of "remembered": a face or detail with at least
  /// [threshold] points.
  static bool isRemembered(int points, int threshold) => points >= threshold;

  final int faces;
  final int details;

  bool get isNothing => faces == 0 && details == 0;

  @override
  bool operator ==(Object other) =>
      other is RememberedCount &&
      other.faces == faces &&
      other.details == details;

  @override
  int get hashCode => Object.hash(faces, details);

  @override
  String toString() => 'RememberedCount($faces faces, $details details)';
}
