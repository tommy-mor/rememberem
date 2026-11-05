import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/contacts/contact_open_result.dart';
import 'package:rememberem/src/memories/memory_edit_screen.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_contacts_service.dart';
import 'fakes/fake_memory_repository.dart';
import 'fakes/test_services.dart';

void main() {
  late FakeMemoryRepository repository;
  late FakeContactsService contacts;
  late Memory memory;
  final navigator = GlobalKey<NavigatorState>();

  setUp(() async {
    repository = FakeMemoryRepository();
    contacts = FakeContactsService()..systemPick = 'ann';
    final m = await repository.add(photoJpeg: [], capturedAt: DateTime(2026));
    memory = m.withField('name', 'Ann Lee');
    await repository.save(memory);
  });

  Future<void> showCard(WidgetTester tester, {bool withContacts = true}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigator, home: const Text('list')),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => MemoryEditScreen(
          memory: repository.stored[memory.id]!,
          services: testServices(
            repository,
            contacts: withContacts ? contacts : null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a tap opens the phone picker; choosing links only its key', (
    tester,
  ) async {
    await showCard(tester);

    await tester.tap(find.byTooltip('Link to a contact'));
    await tester.pumpAndSettle();

    expect(contacts.calls, ['pick']);
    expect(repository.contactLinks, [(memory.id, 'ann')]);
    expect(repository.stored[memory.id]!.toJson()['contactKey'], 'ann');
    expect(find.byTooltip('Open contact'), findsOneWidget);
  });

  testWidgets('linked, a tap opens the contact; a missing one says so and '
      'keeps the link', (tester) async {
    await repository.setContactKey(memory.id, 'ann');
    await showCard(tester);

    await tester.tap(find.byTooltip('Open contact'));
    await tester.pumpAndSettle();
    expect(contacts.calls, ['open ann']);

    contacts.openResult = ContactOpenResult.notFound;
    await tester.tap(find.byTooltip('Open contact'));
    await tester.pump();
    expect(find.textContaining('Contact not found'), findsOneWidget);
    expect(repository.stored[memory.id]!.contactKey, 'ann');

    contacts.openResult = ContactOpenResult.noApp;
    await tester.tap(find.byTooltip('Open contact'));
    await tester.pump();
    expect(find.textContaining('no contacts app'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long press offers re-assign and remove; remove only unlinks', (
    tester,
  ) async {
    await repository.setContactKey(memory.id, 'ann');
    await showCard(tester);

    await tester.longPress(find.byTooltip('Open contact'));
    await tester.pumpAndSettle();
    expect(find.text('Re-assign contact'), findsOneWidget);
    await tester.tap(find.text('Remove link'));
    await tester.pumpAndSettle();

    expect(repository.stored[memory.id]!.contactKey, isNull);
    expect(contacts.calls, isEmpty); // nothing touched on the phone
    expect(find.byTooltip('Link to a contact'), findsOneWidget);

    await repository.setContactKey(memory.id, 'ann');
    await showCard(tester);
    await tester.longPress(find.byTooltip('Open contact'));
    await tester.pumpAndSettle();
    contacts.systemPick = 'other';
    await tester.tap(find.text('Re-assign contact'));
    await tester.pumpAndSettle();
    expect(repository.stored[memory.id]!.contactKey, 'other');
  });

  testWidgets('backing out of the phone picker changes nothing', (
    tester,
  ) async {
    contacts.systemPick = null;
    await showCard(tester);

    await tester.tap(find.byTooltip('Link to a contact'));
    await tester.pumpAndSettle();

    expect(contacts.calls, ['pick']);
    expect(repository.contactLinks, isEmpty);
    expect(find.byTooltip('Link to a contact'), findsOneWidget);
  });

  testWidgets('taps while a call is in flight are ignored; a late answer '
      'after leaving links nothing', (tester) async {
    contacts.pickGate = Completer<void>();
    await showCard(tester);

    await tester.tap(find.byTooltip('Link to a contact'));
    await tester.pump();
    await tester.tap(find.byTooltip('Link to a contact'));
    await tester.pump();
    expect(contacts.calls, ['pick']);

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    contacts.pickGate!.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(repository.contactLinks, isEmpty);
  });

  testWidgets('a name autosave after linking keeps the link', (tester) async {
    await showCard(tester);
    await tester.tap(find.byTooltip('Link to a contact'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'NAME'),
      'Ann B. Lee',
    );
    await tester.pump(const Duration(seconds: 1));

    expect(repository.stored[memory.id]!.contactKey, 'ann');
    expect(repository.stored[memory.id]!.displayName, 'Ann B. Lee');
  });

  testWidgets('with no contacts service there is no icon', (tester) async {
    await showCard(tester, withContacts: false);

    expect(find.byTooltip('Link to a contact'), findsNothing);
  });
}
