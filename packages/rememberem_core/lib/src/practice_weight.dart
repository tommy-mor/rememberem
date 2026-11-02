import 'dart:math';

/// How strongly practice should prefer an item: higher for few points and
/// for a long time since it was last right (never counts as 60 days).
/// Always positive and finite.
double practiceWeight(int points, DateTime? lastCorrect, DateTime now) {
  final days = lastCorrect == null
      ? 60.0
      : max(0, now.difference(lastCorrect).inHours / 24).toDouble();
  return 1 / (1 + max(0, points)) + min(days, 60) / 30;
}
