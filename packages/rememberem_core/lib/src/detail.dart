/// One timestamped fact about a person, such as "Sings in the choir".
class Detail {
  Detail({
    required this.id,
    required this.text,
    required DateTime at,
    this.points = 0,
    DateTime? lastCorrectDate,
  })  : at = at.toUtc(),
        lastCorrectDate = lastCorrectDate?.toUtc();

  /// Unknown keys are ignored, so later stories can add fields freely.
  factory Detail.fromJson(Map<String, dynamic> json) => Detail(
        id: json['id'] as String,
        text: json['text'] as String,
        at: DateTime.parse(json['at'] as String),
        points: json['points'] as int? ?? 0,
        lastCorrectDate: json['lastCorrectDate'] == null
            ? null
            : DateTime.parse(json['lastCorrectDate'] as String),
      );

  final String id;
  final String text;

  /// When the detail was recorded (Fred may re-date it), in UTC.
  final DateTime at;

  /// Details practice: first-try-correct answers in a row (a miss resets
  /// it). Follows the detail through text edits and re-dating.
  final int points;

  /// When Fred last matched this detail first try (UTC), or null.
  final DateTime? lastCorrectDate;

  Detail copyWith({String? text, DateTime? at}) => Detail(
        id: id,
        text: text ?? this.text,
        at: at ?? this.at,
        points: points,
        lastCorrectDate: lastCorrectDate,
      );

  Detail withScore(int points, DateTime? lastCorrectDate) => Detail(
        id: id,
        text: text,
        at: at,
        points: points,
        lastCorrectDate: lastCorrectDate,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'at': at.toIso8601String(),
        if (points != 0) 'points': points,
        if (lastCorrectDate != null)
          'lastCorrectDate': lastCorrectDate!.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      other is Detail &&
      other.id == id &&
      other.text == text &&
      other.at.isAtSameMomentAs(at) &&
      other.points == points &&
      (other.lastCorrectDate == null
          ? lastCorrectDate == null
          : lastCorrectDate != null &&
              other.lastCorrectDate!.isAtSameMomentAs(lastCorrectDate!));

  @override
  int get hashCode => Object.hash(
        id,
        text,
        at.microsecondsSinceEpoch,
        points,
        lastCorrectDate?.microsecondsSinceEpoch,
      );

  @override
  String toString() => 'Detail($id, "$text", $at, $points)';
}
