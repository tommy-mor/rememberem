import 'detail.dart';
import 'encounter.dart';
import 'geo_point.dart';
import 'memory_field.dart';

/// One remembered person: every time Fred met them (each with a private
/// photo) plus everything noted about them.
class Memory {
  /// [encounters] must not be empty; they are kept newest first.
  Memory({
    required this.id,
    required List<Encounter> encounters,
    Map<String, String> fields = const {},
    List<Detail> details = const [],
    this.trashedAt,
    this.points = 0,
    DateTime? lastCorrectDate,
  })  : assert(encounters.isNotEmpty),
        lastCorrectDate = lastCorrectDate?.toUtc(),
        encounters = List.unmodifiable(
          List<Encounter>.of(encounters)..sort(Encounter.newestFirst),
        ),
        fields = Map.unmodifiable(fields),
        details = List.unmodifiable(details);

  /// A person met once, as a capture creates them.
  factory Memory.captured({
    required String id,
    required String photoFileName,
    required DateTime capturedAt,
    GeoPoint? location,
    String place = '',
    String meeting = '',
    Map<String, String> fields = const {},
    List<Detail> details = const [],
    DateTime? trashedAt,
  }) =>
      Memory(
        id: id,
        encounters: [
          Encounter(
            photoFileName: photoFileName,
            capturedAt: capturedAt,
            location: location,
            place: place,
            meeting: meeting,
          ),
        ],
        fields: fields,
        details: details,
        trashedAt: trashedAt,
      );

  factory Memory.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final fields = (json['fields'] as Map<String, dynamic>? ?? {})
        .map((key, value) => MapEntry(key, value as String));
    // Before encounters, one photo, time and location sat at the top level
    // with place and meeting in fields.
    final legacyPlace = fields.remove(MemoryField.place.key) ?? '';
    final legacyMeeting = fields.remove(MemoryField.meeting.key) ?? '';
    final List<Encounter> encounters;
    if (json.containsKey(_encountersKey)) {
      encounters = [
        for (final item in json[_encountersKey] as List<dynamic>)
          Encounter.fromJson(item as Map<String, dynamic>),
      ];
    } else {
      encounters = [
        Encounter.fromJson(json)
            .withPlace(legacyPlace)
            .withMeeting(legacyMeeting),
      ];
    }
    // Before details were a list they were one string in fields['details'].
    final legacyDetails = fields.remove(_legacyDetailsKey);
    final List<Detail> details;
    if (json.containsKey(_detailsKey)) {
      details = [
        for (final item in json[_detailsKey] as List<dynamic>)
          Detail.fromJson(item as Map<String, dynamic>),
      ];
    } else if (legacyDetails != null && legacyDetails.trim().isNotEmpty) {
      details = [
        Detail(
          id: '$id-legacy',
          text: legacyDetails,
          at: encounters.last.capturedAt,
        ),
      ];
    } else {
      details = const [];
    }
    return Memory(
      id: id,
      encounters: encounters,
      fields: fields,
      details: details,
      trashedAt: json['trashedAt'] == null
          ? null
          : DateTime.parse(json['trashedAt'] as String),
      points: json['points'] as int? ?? 0,
      lastCorrectDate: json['lastCorrectDate'] == null
          ? null
          : DateTime.parse(json['lastCorrectDate'] as String),
    );
  }

  static const _encountersKey = 'encounters';
  static const _detailsKey = 'detailItems';
  static const _legacyDetailsKey = 'details';

  final String id;

  /// Every meeting with this person, newest first. Never empty.
  final List<Encounter> encounters;

  /// Free-form notes keyed by name, such as the name. Place and meeting
  /// belong to each [Encounter].
  final Map<String, String> fields;

  /// Timestamped facts, in the order they were added.
  final List<Detail> details;

  /// When this person was moved to the trash; null while they are active.
  final DateTime? trashedAt;

  /// Face practice: first-try-correct answers in a row (a miss resets it).
  final int points;

  /// When Fred last named this face first try (UTC), or null.
  final DateTime? lastCorrectDate;

  /// The newest encounter: its photo represents the person everywhere.
  Encounter get latest => encounters.first;

  String get photoFileName => latest.photoFileName;
  DateTime get capturedAt => latest.capturedAt;
  GeoPoint? get location => latest.location;

  /// Name from [fields]; place and meeting from the [latest] encounter.
  String field(MemoryField field) => switch (field) {
        MemoryField.place => latest.place,
        MemoryField.meeting => latest.meeting,
        _ => fields[field.key] ?? '',
      };

  /// Sets a field; place and meeting go to the [latest] encounter.
  Memory withField(String key, String value) {
    if (key == MemoryField.place.key) {
      return withEncounters([latest.withPlace(value), ...encounters.skip(1)]);
    }
    if (key == MemoryField.meeting.key) {
      return withEncounters([latest.withMeeting(value), ...encounters.skip(1)]);
    }
    return _copy(fields: {...fields, key: value});
  }

  Memory withDetails(List<Detail> details) => _copy(details: details);

  /// This record with each detail's practice score taken from [onDisk]
  /// (matched by id), wholesale: the stored score always wins over an
  /// in-memory copy, so a stale editor save never undoes a game result.
  /// Details not on disk keep their own score; none are added.
  Memory withDetailScores(List<Detail> onDisk) {
    final stored = {for (final d in onDisk) d.id: d};
    return withDetails([
      for (final d in details)
        if (stored[d.id] case final disk?)
          d.withScore(disk.points, disk.lastCorrectDate)
        else
          d,
    ]);
  }

  Memory withEncounters(List<Encounter> encounters) =>
      _copy(encounters: encounters);

  Memory withTrashedAt(DateTime? at) => Memory(
        id: id,
        encounters: encounters,
        fields: fields,
        details: details,
        trashedAt: at,
        points: points,
        lastCorrectDate: lastCorrectDate,
      );

  /// This person with face-practice score [points] and [lastCorrectDate].
  Memory withScore(int points, DateTime? lastCorrectDate) => Memory(
        id: id,
        encounters: encounters,
        fields: fields,
        details: details,
        trashedAt: trashedAt,
        points: points,
        lastCorrectDate: lastCorrectDate,
      );

  /// This person with [other] folded in: [other]'s name if it has one, and
  /// every encounter and detail of both. On a clash this person's copy
  /// wins, so merging the same pair twice changes nothing. The practice
  /// score stays this person's own.
  Memory merged(Memory other) {
    final otherName = other.fields[MemoryField.name.key] ?? '';
    final photos = {for (final e in encounters) e.photoFileName};
    final detailIds = {for (final d in details) d.id};
    return Memory(
      id: id,
      encounters: [
        ...encounters,
        for (final e in other.encounters)
          if (!photos.contains(e.photoFileName)) e,
      ],
      fields: {
        ...fields,
        if (otherName.trim().isNotEmpty) MemoryField.name.key: otherName,
      },
      details: [
        ...details,
        for (final d in other.details)
          if (!detailIds.contains(d.id)) d,
      ]..sort((a, b) => a.at.compareTo(b.at)),
      trashedAt: trashedAt,
      points: points,
      lastCorrectDate: lastCorrectDate,
    );
  }

  Memory _copy({
    List<Encounter>? encounters,
    Map<String, String>? fields,
    List<Detail>? details,
  }) =>
      Memory(
        id: id,
        encounters: encounters ?? this.encounters,
        fields: fields ?? this.fields,
        details: details ?? this.details,
        trashedAt: trashedAt,
        points: points,
        lastCorrectDate: lastCorrectDate,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'fields': fields,
        _encountersKey: encounters,
        _detailsKey: details,
        if (trashedAt != null)
          'trashedAt': trashedAt!.toUtc().toIso8601String(),
        if (points != 0) 'points': points,
        if (lastCorrectDate != null)
          'lastCorrectDate': lastCorrectDate!.toIso8601String(),
      };
}
