import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/app/app_services.dart';
import 'package:rememberem/src/app/meet_shortcut.dart';
import 'package:rememberem/src/app/rememberem_app.dart';
import 'package:rememberem/src/capture/capture_screen.dart';
import 'package:rememberem/src/location/device_location.dart';
import 'package:rememberem/src/memories/encounter_edit_screen.dart';
import 'package:rememberem/src/memories/memory_edit_screen.dart';
import 'package:rememberem/src/memories/merge_picker_screen.dart';
import 'package:rememberem/src/memories/person_card_route.dart';
import 'package:rememberem/src/places/places_screen.dart';
import 'package:rememberem/src/practice/detail_game_screen.dart';
import 'package:rememberem/src/practice/face_game_screen.dart';
import 'package:rememberem/src/timeline/timeline_screen.dart';
import 'package:rememberem/src/trash/trash_screen.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_dictation.dart';
import 'fakes/fake_memory_repository.dart';

class _NoFaces implements FaceLocator {
  @override
  Future<List<PixelRect>> findFaces(File photo) async => [];
}

/// Captures the shortcut callback instead of talking to the platform.
class _FakeShortcut extends MeetShortcut {
  void Function()? trigger;

  @override
  Future<void> install(void Function() onMeet) async => trigger = onMeet;
}

class _FailingSaves extends FakeMemoryRepository {
  bool fail = false;

  @override
  Future<void> save(Memory memory) {
    if (fail) throw const FileSystemException('disk full');
    return super.save(memory);
  }
}

void main() {
  late FakeMemoryRepository repository;
  late AppServices services;
  late _FakeShortcut shortcut;

  Future<void> people(List<String> names) async {
    for (final (i, name) in names.indexed) {
      final m = await repository.add(
        photoJpeg: [],
        capturedAt: DateTime(2026, 10, i + 1, 10),
        place: 'Cafe',
      );
      await repository.save(
        m.withField('name', name).withDetails([
          Detail(
            id: '${m.id}-d',
            text: 'Detail $i',
            at: DateTime(2026, 10, i + 1, 10),
          ),
        ]),
      );
    }
  }

  Future<void> boot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    services = AppServices(
      repository: repository,
      capture: PortraitCapture(
        repository: repository,
        faceLocator: _NoFaces(),
        workFolder: Directory.systemTemp,
      ),
      dictation: FakeDictation(),
      location: DeviceLocation(),
    );
    shortcut = _FakeShortcut();
    await tester.pumpWidget(
      RememberemApp(services: services, shortcut: shortcut),
    );
    await tester.pumpAndSettle();
  }

  NavigatorState navigator(WidgetTester tester) =>
      tester.state<NavigatorState>(find.byType(Navigator).first);

  /// The device Back button.
  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  void expectList(WidgetTester tester) {
    expect(find.bySemanticsLabel('Rememberem'), findsOneWidget);
    expect(navigator(tester).canPop(), isFalse);
  }

  Future<void> open(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Pumps without settling: the camera page spins forever with no camera.
  Future<void> settleCamera(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  setUp(() async {
    repository = FakeMemoryRepository();
    await people(['Ann', 'Bo', 'Cy', 'Di']);
  });

  testWidgets('card, then picture: Back twice returns to the list', (
    tester,
  ) async {
    await boot(tester);
    await open(tester, find.text('Ann'));
    await open(tester, find.byTooltip('Open this picture'));
    expect(find.byType(EncounterEditScreen), findsOneWidget);

    await back(tester);
    expect(find.byType(MemoryEditScreen), findsOneWidget);
    await back(tester);
    expectList(tester);
  });

  testWidgets('Home from a card over a day of the timeline: the list, '
      'saved', (tester) async {
    await boot(tester);
    await open(tester, find.byTooltip('Timeline'));
    await open(tester, find.text('Thursday, October 1, 2026'));
    await open(tester, find.text('Ann'));
    await tester.enterText(find.widgetWithText(TextField, 'Ann'), 'Annie');

    await tester.tap(find.byTooltip('Home'));
    await tester.pumpAndSettle();

    expectList(tester);
    expect(find.text('Annie'), findsOneWidget);
  });

  testWidgets('timeline, a day, then a card: Back three times', (tester) async {
    await boot(tester);
    await open(tester, find.byTooltip('Timeline'));
    await open(tester, find.text('Thursday, October 1, 2026'));
    await open(tester, find.text('Ann'));
    expect(find.byType(MemoryEditScreen), findsOneWidget);

    await back(tester);
    expect(find.byType(TimelineScreen), findsOneWidget);
    expect(find.text('Bo'), findsNothing); // still the one-day view
    await back(tester);
    expect(find.text('Bo'), findsOneWidget); // the full timeline
    await back(tester);
    expectList(tester);
  });

  testWidgets('places, trash and both games each go back in one press', (
    tester,
  ) async {
    await boot(tester);
    for (final (opener, page) in [
      (find.byTooltip('Places'), PlacesScreen),
      (find.byTooltip('Trash'), TrashScreen),
      (find.widgetWithText(OutlinedButton, 'Faces'), FaceGameScreen),
      (find.widgetWithText(OutlinedButton, 'Details'), DetailGameScreen),
    ]) {
      await open(tester, opener);
      expect(find.byType(page), findsOneWidget);
      await back(tester);
      expectList(tester);
    }
  });

  testWidgets('the merge picker goes back to the card', (tester) async {
    await boot(tester);
    await open(tester, find.text('Ann'));
    await open(tester, find.text('Merge with existing person'));
    expect(find.byType(MergePickerScreen), findsOneWidget);

    await back(tester);
    expect(find.byType(MemoryEditScreen), findsOneWidget);
  });

  testWidgets('after a capture, Back from the notes skips the camera', (
    tester,
  ) async {
    await boot(tester);
    await tester.tap(find.text('Meet someone'));
    await settleCamera(tester);
    expect(find.byType(CaptureScreen), findsOneWidget);
    // What the shutter does: the notes page replaces the camera.
    final added = await repository.add(
      photoJpeg: [],
      capturedAt: DateTime(2026, 11, 1),
    );
    navigator(tester)
        .pushReplacement(PersonCardRoute(services: services, memory: added));
    await tester.pumpAndSettle();

    await back(tester);
    expectList(tester);
  });

  testWidgets('two quick Backs on a card pop exactly one page and save', (
    tester,
  ) async {
    await boot(tester);
    await open(tester, find.text('Ann'));
    await tester.enterText(find.widgetWithText(TextField, 'Ann'), 'Annie');

    tester.binding.handlePopRoute();
    tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expectList(tester);
    expect(find.text('Annie'), findsOneWidget);
  });

  testWidgets('a failing save never traps Back', (tester) async {
    repository = _FailingSaves();
    await people(['Ann', 'Bo', 'Cy', 'Di']);
    await boot(tester);
    await open(tester, find.text('Ann'));
    (repository as _FailingSaves).fail = true;
    await tester.enterText(find.widgetWithText(TextField, 'Ann'), 'Annie');

    await back(tester);

    expectList(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an open dialog closes first; the page stays', (tester) async {
    await boot(tester);
    await open(tester, find.byTooltip('Places'));
    await tester.enterText(find.widgetWithText(TextField, 'Cafe'), 'Diner');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await back(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(PlacesScreen), findsOneWidget);
  });

  testWidgets('the shortcut from deep inside leaves list then camera; a '
      'second trigger is ignored; it works again from the notes', (
    tester,
  ) async {
    await boot(tester);
    await open(tester, find.text('Ann'));
    await open(tester, find.byTooltip('Open this picture'));

    shortcut.trigger!();
    await settleCamera(tester);
    shortcut.trigger!();
    await settleCamera(tester);
    expect(find.byType(CaptureScreen), findsOneWidget);
    await back(tester);
    expectList(tester);

    await tester.tap(find.text('Meet someone'));
    await settleCamera(tester);
    final added = await repository.add(
      photoJpeg: [],
      capturedAt: DateTime(2026, 11, 1),
    );
    navigator(tester)
        .pushReplacement(PersonCardRoute(services: services, memory: added));
    await tester.pumpAndSettle();
    shortcut.trigger!();
    await settleCamera(tester);
    expect(find.byType(CaptureScreen), findsOneWidget);
    await back(tester);
    expectList(tester);
  });
}
