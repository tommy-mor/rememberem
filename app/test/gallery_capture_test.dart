import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
// Rational is not exported, but phones write GPS as rationals.
// ignore: implementation_imports
import 'package:image/src/util/rational.dart';
import 'package:rememberem/src/capture/capture_screen.dart';
import 'package:rememberem/src/capture/photo_picker.dart';
import 'package:rememberem/src/capture/picked_photo.dart';
import 'package:rememberem/src/memories/memory_edit_screen.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_memory_repository.dart';
import 'fakes/recording_capture.dart';
import 'fakes/test_services.dart';

class _FakePicker implements PhotoPicker {
  _FakePicker(this.photo, {this.original = true});

  final List<int>? photo;
  final bool original;
  int settingsOpened = 0;

  @override
  Future<PickedPhoto?> pick() async {
    final bytes = photo;
    return bytes == null ? null : PickedPhoto(bytes, original: original);
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}

List<int> photoWithExif() {
  final image = img.Image(width: 8, height: 8);
  final gps = image.exif.gpsIfd;
  gps.data[0x0001] = img.IfdValueAscii('N');
  gps.data[0x0002] = img.IfdValueRational.list([
    Rational(47, 1),
    Rational(30, 1),
    Rational(0, 1),
  ]);
  gps.data[0x0003] = img.IfdValueAscii('W');
  gps.data[0x0004] = img.IfdValueRational.list([
    Rational(122, 1),
    Rational(15, 1),
    Rational(0, 1),
  ]);
  image.exif.exifIfd.data[0x9003] = img.IfdValueAscii('2026:10:27 15:04:05');
  return img.encodeJpg(image);
}

void main() {
  late FakeMemoryRepository repository;
  late RecordingCapture capture;

  setUp(() {
    repository = FakeMemoryRepository();
    capture = RecordingCapture(repository);
  });

  late _FakePicker picker;

  Future<void> showCamera(
    WidgetTester tester,
    List<int>? photo, {
    bool original = true,
  }) async {
    picker = _FakePicker(photo, original: original);
    await tester.pumpWidget(
      MaterialApp(
        home: CaptureScreen(
          services: testServices(
            repository,
            capture: capture,
            photoPicker: picker,
            // Where the phone is now must not be used for an old photo.
            location: FakeLocation(const GeoPoint(1, 1)),
          ),
          routeObserver: RouteObserver<ModalRoute<void>>(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('a chosen photo is saved with its own GPS and time, then the '
      'notes open', (tester) async {
    await showCamera(tester, photoWithExif());

    await tester.tap(find.byTooltip('Choose a photo from the phone'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final call = capture.calls.single;
    expect(call.capturedAt, DateTime(2026, 10, 27, 15, 4, 5));
    expect(call.location!.latitude, closeTo(47.5, 1e-9));
    expect(call.location!.longitude, closeTo(-122.25, 1e-9));
    expect(find.byType(MemoryEditScreen), findsOneWidget);
  });

  testWidgets('a photo without EXIF has no location, not the phone\'s', (
    tester,
  ) async {
    await showCamera(tester, img.encodeJpg(img.Image(width: 8, height: 8)));

    await tester.tap(find.byTooltip('Choose a photo from the phone'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(capture.calls.single.location, isNull);
  });

  testWidgets('changing your mind saves nothing and keeps the camera', (
    tester,
  ) async {
    await showCamera(tester, null);

    await tester.tap(find.byTooltip('Choose a photo from the phone'));
    await tester.pump();

    expect(capture.calls, isEmpty);
    expect(find.byType(CaptureScreen), findsOneWidget);
    expect(find.byTooltip('Choose a photo from the phone'), findsOneWidget);
  });

  testWidgets('a photo the phone stripped of its location says so and '
      'offers Settings; a location that did come through is used', (
    tester,
  ) async {
    await showCamera(
      tester,
      img.encodeJpg(img.Image(width: 8, height: 8)),
      original: false,
    );
    await tester.tap(find.byTooltip('Choose a photo from the phone'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('No location came'), findsOneWidget);
    await tester.tap(find.text('Settings'));
    expect(picker.settingsOpened, 1);

    await tester.pumpWidget(const SizedBox());
    await showCamera(tester, photoWithExif(), original: false);
    await tester.tap(find.byTooltip('Choose a photo from the phone'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(capture.calls.last.location, isNotNull);
  });
}
