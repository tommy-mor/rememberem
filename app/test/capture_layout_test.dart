import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/capture/capture_screen.dart';
import 'package:rememberem/src/capture/face_box.dart';
import 'package:rememberem/src/capture/face_picker_screen.dart';
import 'package:rememberem/src/capture/group_details_screen.dart';
import 'package:rememberem/src/capture/photo_check.dart';
import 'package:rememberem/src/capture/photo_picker.dart';
import 'package:rememberem/src/capture/picked_photo.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_memory_repository.dart';
import 'fakes/test_services.dart';

class _Gallery implements PhotoPicker {
  @override
  Future<PickedPhoto?> pick() async => null;

  @override
  Future<void> openSettings() async {}
}

/// The capture screens' chrome, at large text on a small phone and on its
/// side. The camera preview is a platform view and cannot be pumped, so the
/// camera screen is shown without a camera: its shutter row is the same
/// code, but the consent line (shown only over a live preview) is not
/// covered here.
void main() {
  final repository = FakeMemoryRepository();
  final draft = CaptureDraft(
    photo: UprightPhoto(Uint8List.fromList([1, 2, 3]), 400, 500),
    faces: const [
      PixelRect(20, 100, 60, 80),
      PixelRect(160, 120, 60, 80),
      PixelRect(300, 90, 60, 80),
    ],
    capturedAt: DateTime(2026, 11, 5, 12),
  );

  final screens = <String, Widget Function()>{
    'camera': () => CaptureScreen(
      services: testServices(repository, photoPicker: _Gallery()),
    ),
    'photo check': () =>
        PhotoCheck(jpeg: Uint8List(3), onUse: () {}, onRetake: () {}),
    'face picker': () =>
        FacePickerScreen(draft: draft, services: testServices(repository)),
    'group details': () => GroupDetailsScreen(
      draft: draft,
      faces: draft.faces,
      services: testServices(repository),
    ),
  };

  const sizes = {'568 x 320': Size(568, 320), '320 x 568': Size(320, 568)};

  for (final MapEntry(key: name, value: build) in screens.entries) {
    for (final MapEntry(key: sizeName, value: size) in sizes.entries) {
      testWidgets('$name does not overflow at $sizeName, text scale 2.0', (
        tester,
      ) async {
        tester.view
          ..physicalSize = size
          ..devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(MaterialApp(home: build()));
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('the shutter row: 76 dp shutter, 48 dp gallery on the right', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(360, 640)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: screens['camera']!()));
    await tester.pump();
    await tester.pump();

    final shutter = tester.getRect(find.byTooltip('Take photo'));
    final gallery = tester.getRect(
      find.byTooltip('Choose a photo from the phone'),
    );
    expect(shutter.size, const Size(76, 76));
    expect(gallery.size, const Size(48, 48));
    expect(gallery.left, greaterThan(shutter.right));
    expect(shutter.center.dx, closeTo(180, 0.5));
    expect(gallery.right, 360 - 16);
  });

  testWidgets('the face picker has the strip, and a chosen face shows a '
      'check as well as the fill', (tester) async {
    tester.view
      ..physicalSize = const Size(360, 640)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: screens['face picker']!()));
    await tester.pump();

    expect(find.text('Tap each face to keep'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    await tester.tap(find.byTooltip('Face 1'));
    await tester.pump();
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byType(FaceBox), findsNWidgets(3));
  });

  testWidgets('a face on the group page is a row at least 58 dp tall with a '
      'labelled portrait', (tester) async {
    tester.view
      ..physicalSize = const Size(360, 640)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(home: screens['group details']!()));
    await tester.pump();

    for (final face in ['Face 1', 'Face 2', 'Face 3']) {
      expect(find.bySemanticsLabel(face), findsOneWidget);
      final row = find.ancestor(
        of: find.text(face),
        matching: find.byType(ConstrainedBox),
      );
      expect(
        tester.getSize(row.first).height,
        greaterThanOrEqualTo(58),
        reason: face,
      );
    }
    handle.dispose();
  });
}
