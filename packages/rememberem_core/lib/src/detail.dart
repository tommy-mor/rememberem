/// One timestamped fact about a person, such as "Sings in the choir".
class Detail {
  Detail({required this.id, required this.text, required DateTime at})
      : at = at.toUtc();

  /// Unknown keys are ignored, so later stories can add fields freely.
  factory Detail.fromJson(Map<String, dynamic> json) => Detail(
        id: json['id'] as String,
        text: json['text'] as String,
        at: DateTime.parse(json['at'] as String),
      );

  final String id;
  final String text;

  /// When the detail was first recorded, in UTC.
  final DateTime at;

  Detail copyWith({String? text}) =>
      Detail(id: id, text: text ?? this.text, at: at);

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'at': at.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      other is Detail &&
      other.id == id &&
      other.text == text &&
      other.at.isAtSameMomentAs(at);

  @override
  int get hashCode => Object.hash(id, text, at.microsecondsSinceEpoch);

  @override
  String toString() => 'Detail($id, "$text", $at)';
}
