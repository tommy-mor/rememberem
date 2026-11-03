/// What sort of thing a [Detail] remembers.
enum DetailKind {
  /// Something true about the person; no date, time or place.
  fact('Fact'),

  /// Something that happened, on a date ([Detail.at]) at a place.
  happening('Happening'),

  /// Another person and who they are to this one: "My boss is Jill".
  relationship('Relationship'),

  /// The first time something happened: a birthday, a wedding.
  anniversary('Anniversary'),

  /// A group Fred puts people in ("book club"), with an optional place and
  /// date ([Detail.eventDate]).
  tag('Tag');

  const DetailKind(this.label);

  /// How the kind is shown to Fred.
  final String label;

  /// The kind written as [wireName], or null if unknown.
  static DetailKind? fromWire(Object? wireName) {
    for (final kind in values) {
      if (kind.name == wireName) return kind;
    }
    return null;
  }
}
