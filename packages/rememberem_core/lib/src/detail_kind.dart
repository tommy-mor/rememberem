/// What sort of thing a [Detail] remembers.
enum DetailKind {
  /// Something true about the person; no date, time or place.
  fact('Fact', 'Facts'),

  /// Something that happened, on a date ([Detail.at]) at a place.
  happening('Happening', 'Happenings'),

  /// Another person and who they are to this one: "My boss is Jill".
  relationship('Relationship', 'Relationships'),

  /// The first time something happened: a birthday, a wedding.
  anniversary('Anniversary', 'Anniversaries'),

  /// A group Fred puts people in ("book club"), with an optional place and
  /// date ([Detail.eventDate]).
  tag('Tag', 'Tags');

  const DetailKind(this.label, this.plural);

  /// How the kind is shown to Fred.
  final String label;

  /// Its heading over a list of them: "Anniversaries".
  final String plural;

  /// The kind written as [wireName], or null if unknown.
  static DetailKind? fromWire(Object? wireName) {
    for (final kind in values) {
      if (kind.name == wireName) return kind;
    }
    return null;
  }
}
