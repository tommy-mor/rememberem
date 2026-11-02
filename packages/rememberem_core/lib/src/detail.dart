import 'detail_kind.dart';

/// One thing remembered about a person: a fact, a happening, a
/// relationship or an anniversary ([kind]), always with a description
/// ([text]).
class Detail {
  Detail({
    required this.id,
    required this.text,
    required DateTime at,
    DetailKind? type,
    this.place,
    this.targetId,
    this.label,
    this.eventDate,
    this.points = 0,
    DateTime? lastCorrectDate,
  })  : _type = type,
        at = at.toUtc(),
        lastCorrectDate = lastCorrectDate?.toUtc();

  /// Unknown keys are ignored. The keys added with typed details are read
  /// defensively: a bad value loses only that value, never the detail (one
  /// throw here would hide every record).
  factory Detail.fromJson(Map<String, dynamic> json) => Detail(
        id: json['id'] as String,
        text: json['text'] as String,
        at: DateTime.parse(json['at'] as String),
        type: DetailKind.fromWire(json['type']),
        place: _string(json['place']),
        targetId: _string(json['targetId']),
        label: _string(json['label']),
        eventDate: _date(json['eventDate']),
        points: json['points'] as int? ?? 0,
        lastCorrectDate: json['lastCorrectDate'] == null
            ? null
            : DateTime.parse(json['lastCorrectDate'] as String),
      );

  static String? _string(Object? value) => value is String ? value : null;

  static final _datePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  /// A calendar date written as YYYY-MM-DD, or null if it is not one.
  static DateTime? _date(Object? value) {
    if (value is! String) return null;
    final match = _datePattern.firstMatch(value);
    if (match == null) return null;
    final [year, month, day] = [
      for (var i = 1; i <= 3; i++) int.parse(match[i]!),
    ];
    final date = DateTime(year, month, day);
    return date.month == month && date.day == day ? date : null;
  }

  final String id;

  /// The description. May be blank once the detail has other data, such
  /// as a relationship's person.
  final String text;

  /// When the detail was recorded, in UTC. For a happening, when it
  /// happened (Fred may change it).
  final DateTime at;

  /// The kind as stored: null for details written before kinds existed,
  /// which read as facts. Kept apart so those stay recognisable.
  final DetailKind? _type;

  DetailKind get kind => _type ?? DetailKind.fact;

  /// True if nothing has been entered: no description, place, type,
  /// person or date. An empty detail is never saved.
  bool get isEmpty =>
      text.trim().isEmpty &&
      (place?.trim() ?? '').isEmpty &&
      (label?.trim() ?? '').isEmpty &&
      targetId == null &&
      eventDate == null;

  /// Where a happening happened.
  final String? place;

  /// The other person in a relationship (their memory id). Names are looked
  /// up when shown, so correcting a name never breaks the link.
  final String? targetId;

  /// The relationship type ("boss": the other person is this one's boss) or
  /// the anniversary type ("wedding").
  final String? label;

  /// An anniversary's first date: a calendar day (local, no time).
  final DateTime? eventDate;

  /// Details practice: first-try-correct answers in a row (a miss resets
  /// it). Follows the detail through every edit.
  final int points;

  /// When Fred last matched this detail first try (UTC), or null.
  final DateTime? lastCorrectDate;

  /// A copy with the given parts changed; the kind and score are kept.
  /// [targetId] uses a function so it can be cleared to null.
  Detail copyWith({
    String? id,
    String? text,
    DateTime? at,
    String? place,
    String? label,
    DateTime? eventDate,
    String? Function()? targetId,
  }) =>
      Detail(
        id: id ?? this.id,
        text: text ?? this.text,
        at: at ?? this.at,
        type: _type,
        place: place ?? this.place,
        targetId: targetId == null ? this.targetId : targetId(),
        label: label ?? this.label,
        eventDate: eventDate ?? this.eventDate,
        points: points,
        lastCorrectDate: lastCorrectDate,
      );

  Detail withScore(int points, DateTime? lastCorrectDate) => Detail(
        id: id,
        text: text,
        at: at,
        type: _type,
        place: place,
        targetId: targetId,
        label: label,
        eventDate: eventDate,
        points: points,
        lastCorrectDate: lastCorrectDate,
      );

  static String _two(int n) => n.toString().padLeft(2, '0');

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'at': at.toIso8601String(),
        if (_type != null) 'type': _type.name,
        if (place != null) 'place': place,
        if (targetId != null) 'targetId': targetId,
        if (label != null) 'label': label,
        if (eventDate case final d?)
          'eventDate': '${d.year.toString().padLeft(4, '0')}-'
              '${_two(d.month)}-${_two(d.day)}',
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
      other._type == _type &&
      other.place == place &&
      other.targetId == targetId &&
      other.label == label &&
      other.eventDate == eventDate &&
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
        _type,
        place,
        targetId,
        label,
        eventDate,
        points,
        lastCorrectDate?.microsecondsSinceEpoch,
      );

  @override
  String toString() => 'Detail($id, ${kind.name}, "$text", $at, $points)';
}
