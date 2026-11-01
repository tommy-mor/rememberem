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
  }) : fields = Map.unmodifiable(fields);

  factory Memory.fromJson(Map<String, dynamic> json) => Memory(
        id: json['id'] as String,
        photoFileName: json['photo'] as String,
        capturedAt: DateTime.parse(json['capturedAt'] as String),
        location: json['location'] == null
            ? null
            : GeoPoint.fromJson(json['location'] as Map<String, dynamic>),
        fields: (json['fields'] as Map<String, dynamic>? ?? {})
            .map((key, value) => MapEntry(key, value as String)),
      );

  final String id;

  /// File name of the photo, relative to the repository's storage folder.
  final String photoFileName;
  final DateTime capturedAt;

  /// Where the device was when the photo was taken, if it could be found.
  final GeoPoint? location;

  /// Free-form notes keyed by name, e.g. the [MemoryField] keys.
  final Map<String, String> fields;

  String field(MemoryField field) => fields[field.key] ?? '';

  Memory withField(String key, String value) => Memory(
        id: id,
        photoFileName: photoFileName,
        capturedAt: capturedAt,
        location: location,
        fields: {...fields, key: value},
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'photo': photoFileName,
        'capturedAt': capturedAt.toIso8601String(),
        'location': location?.toJson(),
        'fields': fields,
      };
}
