import 'dart:typed_data';

import 'package:image/image.dart' as img;
// Rational is not exported, but phones write GPS as rationals.
// ignore: implementation_imports
import 'package:image/src/util/rational.dart';
import 'package:rememberem_core/rememberem_core.dart';
import 'package:test/test.dart';

/// A tiny JPEG carrying EXIF written the way phones write it: GPS as
/// degree/minute/second rationals and the date as an ASCII string.
Uint8List jpegWith({
  List<Rational>? latitude,
  String latitudeRef = 'N',
  List<Rational>? longitude,
  String longitudeRef = 'E',
  String? taken,
}) {
  final image = img.Image(width: 8, height: 8);
  final gps = image.exif.gpsIfd;
  if (latitude != null) {
    gps.data[0x0001] = img.IfdValueAscii(latitudeRef);
    gps.data[0x0002] = img.IfdValueRational.list(latitude);
  }
  if (longitude != null) {
    gps.data[0x0003] = img.IfdValueAscii(longitudeRef);
    gps.data[0x0004] = img.IfdValueRational.list(longitude);
  }
  if (taken != null) image.exif.exifIfd.data[0x9003] = img.IfdValueAscii(taken);
  return img.encodeJpg(image);
}

List<Rational> dms(int d, int m, int sHundredths) =>
    [Rational(d, 1), Rational(m, 1), Rational(sHundredths, 100)];

void main() {
  final now = DateTime(2026, 11, 2, 12);

  test('reads north-east GPS from degree/minute/second rationals', () {
    final meta = PhotoMetadata.read(
      jpegWith(latitude: dms(47, 53, 4740), longitude: dms(122, 10, 300)),
      now: now,
    );
    expect(meta.location!.latitude, closeTo(47 + 53 / 60 + 47.4 / 3600, 1e-9));
    expect(meta.location!.longitude, closeTo(122 + 10 / 60 + 3 / 3600, 1e-9));
  });

  test('south and west references negate', () {
    final meta = PhotoMetadata.read(
      jpegWith(
        latitude: dms(33, 52, 0),
        latitudeRef: 'S',
        longitude: dms(151, 12, 0),
        longitudeRef: 'W',
      ),
      now: now,
    );
    expect(meta.location!.latitude, lessThan(0));
    expect(meta.location!.longitude, lessThan(0));
  });

  test('reads DateTimeOriginal as local time', () {
    final meta = PhotoMetadata.read(
      jpegWith(taken: '2026:10:27 15:04:05'),
      now: now,
    );
    expect(meta.takenAt, DateTime(2026, 10, 27, 15, 4, 5));
    expect(meta.takenAt!.isUtc, isFalse);
    expect(meta.location, isNull);
  });

  test('a photo without EXIF gives nothing', () {
    final plain = img.encodeJpg(img.Image(width: 8, height: 8));
    final meta = PhotoMetadata.read(plain, now: now);
    expect(meta.location, isNull);
    expect(meta.takenAt, isNull);
  });

  group('never throws on bad input', () {
    final cases = <String, List<int>>{
      'empty': [],
      'garbage': List.filled(64, 7),
      'truncated': jpegWith(latitude: dms(47, 1, 0), longitude: dms(1, 1, 0))
          .sublist(0, 40),
      'a PNG': img.encodePng(img.Image(width: 4, height: 4)),
    };
    for (final entry in cases.entries) {
      test(entry.key, () {
        final meta = PhotoMetadata.read(entry.value, now: now);
        expect(meta.location, isNull);
        expect(meta.takenAt, isNull);
      });
    }
  });

  test('a zero denominator is rejected, not read as 0', () {
    final meta = PhotoMetadata.read(
      jpegWith(
        latitude: [Rational(47, 0), Rational(1, 1), Rational(0, 1)],
        longitude: dms(122, 0, 0),
      ),
      now: now,
    );
    expect(meta.location, isNull);
  });

  test('exactly 0,0 (broken GPS) is no location', () {
    final meta = PhotoMetadata.read(
      jpegWith(latitude: dms(0, 0, 0), longitude: dms(0, 0, 0)),
      now: now,
    );
    expect(meta.location, isNull);
  });

  test('out-of-range coordinates are rejected', () {
    final meta = PhotoMetadata.read(
      jpegWith(latitude: dms(95, 0, 0), longitude: dms(10, 0, 0)),
      now: now,
    );
    expect(meta.location, isNull);
  });

  test('garbage, impossible, ancient and future dates are rejected', () {
    for (final bad in [
      'yesterday',
      '2026:02:30 10:00:00',
      '1999:12:31 23:59:59',
      '2026:11:09 12:00:00',
      '0000:00:00 00:00:00',
    ]) {
      expect(
        PhotoMetadata.read(jpegWith(taken: bad), now: now).takenAt,
        isNull,
        reason: bad,
      );
    }
  });
}
