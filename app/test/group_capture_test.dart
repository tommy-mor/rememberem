import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:rememberem/src/app/app_routes.dart';
import 'package:rememberem/src/capture/capture_screen.dart';
import 'package:rememberem/src/capture/face_box.dart';
import 'package:rememberem/src/capture/face_picker_screen.dart';
import 'package:rememberem/src/capture/group_details_screen.dart';
import 'package:rememberem/src/capture/photo_picker.dart';
import 'package:rememberem/src/capture/picked_photo.dart';
import 'package:rememberem/src/memories/filter_list_screen.dart';
import 'package:rememberem/src/memories/memory_edit_screen.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_memory_repository.dart';
import 'fakes/recording_capture.dart';
import 'fakes/test_services.dart';

class _FakePicker implements PhotoPicker {
  _FakePicker([this.bytes = const [1, 2, 3]]);

  final List<int> bytes;

  @override
  Future<PickedPhoto?> pick() async => PickedPhoto(bytes, original: true);

  @override
  Future<void> openSettings() async {}
}

class _Faces implements FaceLocator {
  _Faces(this.faces);

  final List<PixelRect> faces;

  @override
  Future<List<PixelRect>> findFaces(File photo) async => faces;
}

void main() {
  late FakeMemoryRepository repository;
  late RecordingCapture capture;
  const left = PixelRect(20, 100, 60, 80);
  const middle = PixelRect(160, 120, 60, 80);
  const right = PixelRect(300, 90, 60, 80);

  setUp(() => repository = FakeMemoryRepository());

  /// The list, with the camera opened over it as the app does.
  Future<void> openCamera(
    WidgetTester tester,
    PortraitCapture capture,
    PhotoPicker picker,
  ) async {
    final observer = RouteObserver<ModalRoute<void>>();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [observer],
        home: const Scaffold(body: Text('list')),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: AppRoutes.capture),
        builder: (_) => CaptureScreen(
          services: testServices(
            repository,
            capture: capture,
            photoPicker: picker,
          ),
          routeObserver: observer,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// The camera, then a photo chosen from the phone.
  Future<void> pickPhoto(
    WidgetTester tester, {
    List<PixelRect> faces = const [left, middle, right],
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    capture = RecordingCapture(
      repository,
      faces: faces,
      place: 'Hall',
      meeting: 'Choir',
    );
    await openCamera(tester, capture, _FakePicker());
    await tester.tap(find.byTooltip('Choose a photo from the phone'));
    await tester.pumpAndSettle();
  }

  /// Pumps while real image work runs off the test clock.
  Future<void> settleReal(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  String? routeName(WidgetTester tester, Type page) =>
      ModalRoute.of(tester.element(find.byType(page)))!.settings.name;

  FilledButton addButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton));

  testWidgets('several faces: none chosen at first; taps and All choose; '
      'nothing is saved yet', (tester) async {
    await pickPhoto(tester);

    expect(find.byType(FacePickerScreen), findsOneWidget);
    expect(routeName(tester, FacePickerScreen), AppRoutes.capture);
    expect(find.textContaining('happy to be remembered'), findsOneWidget);
    expect(addButton(tester).onPressed, isNull);

    await tester.tap(find.byTooltip('Face 2'));
    await tester.pump();
    expect(find.text('Add 1 person'), findsOneWidget);
    expect(addButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('All'));
    await tester.pump();
    expect(find.text('Add 3 people'), findsOneWidget);

    await tester.tap(find.byTooltip('Face 1'));
    await tester.pump();
    expect(find.text('Add 2 people'), findsOneWidget);
    expect(repository.stored, isEmpty);
  });

  testWidgets('a small face is still a finger-sized target, and the button '
      'stays clear of messages', (tester) async {
    await pickPhoto(
      tester,
      faces: const [PixelRect(10, 10, 4, 4), PixelRect(200, 10, 4, 4)],
    );

    final target = tester.getSize(find.byType(FaceBox).first);
    expect(target.width, greaterThanOrEqualTo(48));
    expect(target.height, greaterThanOrEqualTo(48));
    final scaffold = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(FacePickerScreen),
        matching: find.byType(Scaffold),
      ),
    );
    expect(scaffold.bottomNavigationBar, isNotNull);
  });

  testWidgets('one face chosen is saved, cropped to it, and its page opens', (
    tester,
  ) async {
    await pickPhoto(tester);

    await tester.tap(find.byTooltip('Face 3'));
    await tester.pump();
    await tester.tap(find.text('Add 1 person'));
    await tester.pumpAndSettle();

    expect(capture.savedFaces, [right]);
    expect(repository.stored, hasLength(1));
    expect(find.byType(MemoryEditScreen), findsOneWidget);
  });

  testWidgets('a photo with one face skips choosing', (tester) async {
    await pickPhoto(tester, faces: [middle]);

    expect(find.byType(FacePickerScreen), findsNothing);
    expect(capture.savedFaces, [middle]);
    expect(find.byType(MemoryEditScreen), findsOneWidget);
  });

  testWidgets('several faces share the place, meeting and details, are left '
      'unnamed, and the Filter List opens on the unknown', (tester) async {
    await pickPhoto(tester);
    await tester.tap(find.text('All'));
    await tester.pump();
    await tester.tap(find.text('Add 3 people'));
    await tester.pumpAndSettle();

    expect(find.byType(GroupDetailsScreen), findsOneWidget);
    expect(routeName(tester, GroupDetailsScreen), AppRoutes.capture);
    expect(find.widgetWithText(TextField, 'Hall'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Choir'), findsOneWidget);
    expect(find.text('Details true of everyone here'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Hall'), 'Town hall');
    await tester.enterText(find.widgetWithText(TextField, 'Detail'), 'Sings');
    await tester.tap(find.text('Add detail'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Detail').last,
      'Tall',
    );
    await tester.tap(find.text('Add detail'));
    await tester.pump(); // a third line left blank

    await tester.tap(find.widgetWithText(FilledButton, 'Add 3 people'));
    await tester.pumpAndSettle();

    final people = repository.stored.values.toList();
    expect(people, hasLength(3));
    expect(capture.savedFaces, [left, middle, right]);
    for (final person in people) {
      expect(person.displayName, Memory.unknownName);
      expect(person.latest.place, 'Town hall');
      expect(person.latest.meeting, 'Choir');
      expect(person.details.map((d) => d.text), ['Sings', 'Tall']);
      expect(person.details.map((d) => d.kind), [
        DetailKind.fact,
        DetailKind.fact,
      ]);
    }
    expect(find.byType(FilterListScreen), findsOneWidget);
    expect(find.text('Add their names while you remember.'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'unknown'), findsOneWidget);
    expect(find.text('3 people'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('list'), findsOneWidget);
  });

  testWidgets('Back from group details returns to choosing faces', (
    tester,
  ) async {
    await pickPhoto(tester);
    await tester.tap(find.text('All'));
    await tester.pump();
    await tester.tap(find.text('Add 3 people'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(FacePickerScreen), findsOneWidget);
    expect(find.text('Add 3 people'), findsOneWidget);
    expect(repository.stored, isEmpty);
  });

  testWidgets('Back from choosing faces asks first; Discard saves nothing', (
    tester,
  ) async {
    await pickPhoto(tester);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard this photo?'), findsOneWidget);
    await tester.tap(find.text('Keep choosing'));
    await tester.pumpAndSettle();
    expect(find.byType(FacePickerScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('list'), findsOneWidget);
    expect(repository.stored, isEmpty);
  });

  testWidgets('Back is held while the group saves, so no one is saved '
      'twice', (tester) async {
    await pickPhoto(tester);
    capture.holdGroup = Completer<void>();
    await tester.tap(find.text('All'));
    await tester.pump();
    await tester.tap(find.text('Add 3 people'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add 3 people'));
    await tester.pump();

    await tester.pageBack();
    await tester.pump();
    expect(find.byType(GroupDetailsScreen), findsOneWidget);

    capture.holdGroup!.complete();
    await tester.pumpAndSettle();
    expect(repository.stored, hasLength(3));
    expect(find.byType(FilterListScreen), findsOneWidget);
  });

  testWidgets('a double tap on Add opens the group page once', (tester) async {
    await pickPhoto(tester);
    await tester.tap(find.text('All'));
    await tester.pump();

    await tester.tap(find.text('Add 3 people'));
    await tester.tap(find.text('Add 3 people'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(GroupDetailsScreen), findsNothing);
    expect(find.byType(FacePickerScreen), findsOneWidget);
    expect(find.text('Add 3 people'), findsOneWidget);
  });

  testWidgets('a failure partway keeps those saved and says so', (
    tester,
  ) async {
    await pickPhoto(tester);
    capture.failGroupAt = 1;
    await tester.tap(find.text('All'));
    await tester.pump();
    await tester.tap(find.text('Add 3 people'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Add 3 people'));
    await tester.pumpAndSettle();

    expect(repository.stored, hasLength(1));
    expect(find.textContaining('Saved 1 of 3 people'), findsOneWidget);
    expect(find.byType(FilterListScreen), findsOneWidget);
  });

  testWidgets('a failure before anyone is saved stays to try again', (
    tester,
  ) async {
    await pickPhoto(tester);
    capture.failGroupAt = 0;
    await tester.tap(find.text('All'));
    await tester.pump();
    await tester.tap(find.text('Add 3 people'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Add 3 people'));
    await tester.pumpAndSettle();

    expect(repository.stored, isEmpty);
    expect(find.textContaining("Couldn't save this photo"), findsOneWidget);
    expect(find.byType(GroupDetailsScreen), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Add 3 people'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('through the real capture: each chosen face is cropped and '
      'saved with the shared details, blank lines left out', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final work = await tester.runAsync(
      () => Directory.systemTemp.createTemp('rememberem_group_'),
    );
    addTearDown(() => tester.runAsync(() => work!.delete(recursive: true)));
    final photo = img.encodeJpg(img.Image(width: 600, height: 800));
    final real = PortraitCapture(
      repository: repository,
      faceLocator: _Faces(const [right, left]),
      workFolder: work!,
    );
    await openCamera(tester, real, _FakePicker(photo));

    await tester.tap(find.byTooltip('Choose a photo from the phone'));
    await settleReal(tester);
    expect(find.byType(FacePickerScreen), findsOneWidget);
    await tester.tap(find.text('All'));
    await tester.pump();
    await tester.tap(find.text('Add 2 people'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Detail'), 'Kind');
    await tester.tap(find.text('Add detail'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add 2 people'));
    await settleReal(tester);

    expect(find.byType(FilterListScreen), findsOneWidget);
    final people = repository.stored.values.toList();
    expect(people, hasLength(2));
    for (final person in people) {
      expect(person.details.map((d) => d.text), ['Kind']);
    }
    // Left to right: the first saved is cropped around the left face.
    final crops = [
      for (final face in [left, right])
        const PortraitFramer().frame(face, 600, 800),
    ];
    final saved = await tester.runAsync(
      () async => [
        for (final p in repository.photos)
          img.decodeJpg(Uint8List.fromList(p))!,
      ],
    );
    expect(
      [for (final i in saved!) (i.width, i.height)],
      [for (final c in crops) (c.width, c.height)],
    );
    expect(await tester.runAsync(() => work.list().toList()), isEmpty);
  });
}
