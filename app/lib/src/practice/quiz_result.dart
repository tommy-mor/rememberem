import 'package:rememberem_core/rememberem_core.dart';

/// One turn of a quiz, for the results at the end: who (and for details,
/// which detail) was asked, whether it was right first try, and the points
/// before and after the answer.
class QuizResult {
  const QuizResult({
    required this.person,
    required this.rightFirstTry,
    required this.pointsBefore,
    required this.pointsAfter,
    this.detailText,
  });

  /// From an answer as recorded: first try right adds a point, a miss
  /// resets to 0, and an answer that could not be saved changes nothing.
  factory QuizResult.answered({
    required Memory person,
    Detail? detail,
    String? detailText,
    required bool rightFirstTry,
    required bool saved,
  }) {
    final before = detail?.points ?? person.points;
    return QuizResult(
      person: person,
      detailText: detailText,
      rightFirstTry: rightFirstTry,
      pointsBefore: before,
      pointsAfter: !saved
          ? before
          : rightFirstTry
          ? before + 1
          : 0,
    );
  }

  final Memory person;

  /// How the detail read in the quiz; null in a face quiz.
  final String? detailText;
  final bool rightFirstTry;
  final int pointsBefore;
  final int pointsAfter;

  /// True if this answer made it remembered.
  bool crossed(int threshold) =>
      !RememberedCount.isRemembered(pointsBefore, threshold) &&
      RememberedCount.isRemembered(pointsAfter, threshold);
}
