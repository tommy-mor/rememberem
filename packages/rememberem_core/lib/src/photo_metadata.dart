import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'geo_point.dart';

/// Where and when a photo from the phone was taken, as far as its EXIF
/// says. Either may be null.
class PhotoMetadata {
  const PhotoMetadata({this.location, this.takenAt});

  /// Reads [jpeg]'s EXIF. Never throws: a file from anywhere may be
  /// malformed, and that must never cost the photo, so anything unreadable
  /// or implausible comes back null. [now] bounds the plausible date.
  factory PhotoMetadata.read(List<int> jpeg, {required DateTime now}) {
    try {
      final exif = img.decodeJpgExif(
        jpeg is Uint8List ? jpeg : Uint8List.fromList(jpeg),
      );
      if (exif == null) return const PhotoMetadata();
      return PhotoMetadata(
        location: _location(exif.gpsIfd),
        takenAt: _takenAt(exif.exifIfd, now),
      );
    } catch (_) {
      return const PhotoMetadata();
    }
  }

  final GeoPoint? location;

  /// Local time, as cameras write it (EXIF has no time zone).
  final DateTime? takenAt;

  // EXIF GPS tags.
  static const _latitudeRef = 0x0001;
  static const _latitude = 0x0002;
  static const _longitudeRef = 0x0003;
  static const _longitude = 0x0004;
  static const _dateTimeOriginal = 0x9003;

  static GeoPoint? _location(img.IfdDirectory gps) {
    final latitude = _degrees(gps.data[_latitude], gps.data[_latitudeRef], 'S');
    final longitude =
        _degrees(gps.data[_longitude], gps.data[_longitudeRef], 'W');
    if (latitude == null || longitude == null) return null;
    if (latitude.abs() > 90 || longitude.abs() > 180) return null;
    // Exactly 0,0 is what broken GPS writes, not a place Fred has been.
    if (latitude == 0 && longitude == 0) return null;
    return GeoPoint(latitude, longitude);
  }

  /// Degrees, minutes and seconds as three rationals, negated when [ref]
  /// is [negative]. Null unless every part is a finite, well-formed number.
  static double? _degrees(
      img.IfdValue? value, img.IfdValue? ref, String negative) {
    if (value is! img.IfdValueRational || value.value.length != 3) return null;
    if (value.value.any((r) => r.denominator == 0)) return null;
    final parts = [for (final r in value.value) r.toDouble()];
    if (parts.any((p) => !p.isFinite || p < 0) ||
        parts[1] >= 60 ||
        parts[2] >= 60) {
      return null;
    }
    final degrees = parts[0] + parts[1] / 60 + parts[2] / 3600;
    final sign = ref?.toString().trim().toUpperCase() == negative ? -1 : 1;
    return sign * degrees;
  }

  static final _exifDate = RegExp(
    r'^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})',
  );

  static DateTime? _takenAt(img.IfdDirectory exif, DateTime now) {
    final match = _exifDate.firstMatch(
      exif.data[_dateTimeOriginal]?.toString().trim() ?? '',
    );
    if (match == null) return null;
    final [year, month, day, hour, minute, second] = [
      for (var i = 1; i <= 6; i++) int.parse(match[i]!),
    ];
    if (month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31 ||
        hour > 23 ||
        minute > 59 ||
        second > 59) {
      return null;
    }
    final at = DateTime(year, month, day, hour, minute, second);
    // DateTime rolls invalid days over (31 April becomes 1 May): reject.
    if (at.day != day || at.month != month) return null;
    if (year < 2000 || at.isAfter(now.add(const Duration(days: 1)))) {
      return null;
    }
    return at;
  }
}
