import 'detail.dart';
import 'geo_point.dart';
import 'memory_field.dart';

/// One remembered person: a private photo plus everything noted about them.
class Memory {
  Memory({
    required this.id,
    required this.photoFileName,
    required this.capturedAt,
    this.location,
    Map<String, String> fields = const {},
    List<Detail> details = const [],
  })  : fields = Map.unmodifiable(fields),
        details = List.unmodifiable(details);

  factory Memory.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final capturedAt = DateTime.parse(json['capturedAt'] as String);
    final fields = (json['fields'] as Map<String, dynamic>? ?? {})
        .map((key, value) => MapEntry(key, value as String));
    // Before details were a list they were one string in fields['details'].
    final legacyDetails = fields.remove(_legacyDetailsKey);
    final List<Detail> details;
    if (json.containsKey(_detailsKey)) {
      details = [
        for (final item in json[_detailsKey] as List<dynamic>)
          Detail.fromJson(item as Map<String, dynamic>),
      ];
    } else if (legacyDetails != null && legacyDetails.trim().isNotEmpty) {
      details = [Detail(id: '$id-legacy', text: legacyDetails, at: capturedAt)];
    } else {
      details = const [];
    }
    return Memory(
      id: id,
      photoFileName: json['photo'] as String,
      capturedAt: capturedAt,
      location: json['location'] == null
          ? null
          : GeoPoint.fromJson(json['location'] as Map<String, dynamic>),
      fields: fields,
      details: details,
    );
  }

  static const _detailsKey = 'detailItems';
  static const _legacyDetailsKey = 'details';

  final String id;

  /// File name of the photo, relative to the repository's storage folder.
  final String photoFileName;
  final DateTime capturedAt;

  /// Where the device was when the photo was taken, if it could be found.
  final GeoPoint? location;

  /// Free-form notes keyed by name, e.g. the [MemoryField] keys.
  final Map<String, String> fields;

  /// Timestamped facts, in the order they were added.
  final List<Detail> details;

  String field(MemoryField field) => fields[field.key] ?? '';

  Memory withField(String key, String value) =>
      _copy(fields: {...fields, key: value});

  Memory withDetails(List<Detail> details) => _copy(details: details);

  Memory _copy({Map<String, String>? fields, List<Detail>? details}) => Memory(
        id: id,
        photoFileName: photoFileName,
        capturedAt: capturedAt,
        location: location,
        fields: fields ?? this.fields,
        details: details ?? this.details,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'photo': photoFileName,
        'capturedAt': capturedAt.toIso8601String(),
        'location': location?.toJson(),
        'fields': fields,
        _detailsKey: details,
      };
}
