import 'dart:io';

import 'package:rememberem/src/app/app_services.dart';
import 'package:rememberem/src/location/device_location.dart';
import 'package:rememberem/src/memories/memory_edit_screen.dart';
import 'package:rememberem/src/memories/memory_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_dictation.dart';
import 'fakes/fake_memory_repository.dart';

class _NoFaces implements FaceLocator {
  @override
  Future<List<PixelRect>> findFaces(File photo) async => [];
}

void main() {
  late FakeMemoryRepository repository;
  late AppServices services;

  setUp(() {
    repository = FakeMemoryRepository();
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
  });

  final navigator = GlobalKey<NavigatorState>();

  Future<void> showScreen(WidgetTester tester,
      {VoidCallback? onMeetSomeone}) async {
    final routeObserver = RouteObserver<ModalRoute<void>>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      navigatorObservers: [routeObserver],
      home: MemoryListScreen(
        services: services,
        routeObserver: routeObserver,
        onMeetSomeone: onMeetSomeone ?? () {},
      ),
    ));
    await tester.pump();
  }

  testWidgets('explains the shortcut when nobody is saved yet',
      (tester) async {
    await showScreen(tester);

    expect(find.textContaining('No one yet'), findsOneWidget);
  });

  testWidgets('lists people with their place and meeting', (tester) async {
    final memory = await repository.add(
      photoJpeg: [],
      capturedAt: DateTime(2026, 11, 1),
    );
    await repository.save(memory
        .withField('name', 'Alex Davis')
        .withField('place', 'Stake Center')
        .withField('meeting', 'Sunday Meetings'));

    await showScreen(tester);

    expect(find.text('Alex Davis'), findsOneWidget);
    expect(find.text('Stake Center · Sunday Meetings'), findsOneWidget);
  });

  testWidgets('Meet someone button starts a capture', (tester) async {
    var started = false;
    await showScreen(tester, onMeetSomeone: () => started = true);

    await tester.tap(find.text('Meet someone'));

    expect(started, isTrue);
  });

  testWidgets(
      'shows the name entered after the camera hands over to the notes screen',
      (tester) async {
    await showScreen(tester);
    // Like the camera screen: pushed, then replaced by the notes screen.
    navigator.currentState!
        .push(MaterialPageRoute<void>(builder: (_) => const Placeholder()));
    await tester.pumpAndSettle();
    final memory =
        await repository.add(photoJpeg: [], capturedAt: DateTime(2026, 11, 1));
    navigator.currentState!.pushReplacement(MaterialPageRoute<void>(
      builder: (_) => MemoryEditScreen(
        memory: memory,
        repository: repository,
        dictation: services.dictation,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Name'), 'Alex Davis');
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(MemoryEditScreen), findsNothing);
    expect(find.text('Alex Davis'), findsOneWidget);
  });
}
