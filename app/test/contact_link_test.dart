import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rememberem/src/contacts/contact_entry.dart';
import 'package:rememberem/src/contacts/contact_matcher.dart';
import 'package:rememberem/src/contacts/contact_open_result.dart';
import 'package:rememberem/src/contacts/contact_picker_dialog.dart';
import 'package:rememberem/src/memories/memory_edit_screen.dart';
import 'package:rememberem_core/rememberem_core.dart';

import 'fakes/fake_contacts_service.dart';
import 'fakes/fake_memory_repository.dart';
import 'fakes/test_services.dart';

void main() {
  group('matcher', () {
    const entries = [
      ContactEntry('1', 'Annabel Cruz'),
      ContactEntry('2', 'Lee, Ann'),
      ContactEntry('3', 'Bo Lee'),
      ContactEntry('4', 'José Núñez'),
    ];

    test('the same words in any order beat a prefix or one shared word', () {
      expect(ContactMatcher.bestIndex(entries, 'Ann Lee'), 1);
      expect(ContactMatcher.bestIndex(entries, 'ann lee '), 1);
    });

    test('non-Latin names match by their own words, never by having none', () {
      const names = [
        ContactEntry('a', '王 小明'),
        ContactEntry('b', 'Иван Петров'),
        ContactEntry('c', '李 华'),
      ];
      expect(ContactMatcher.bestIndex(names, '小明 王'), 0);
      expect(ContactMatcher.bestIndex(names, 'Петров Иван'), 1);
      expect(ContactMatcher.bestIndex(names, '陈 静'), -1);
      expect(ContactMatcher.bestIndex(names, '—'), -1);
    });

    test('accents are ignored; blank or unknown gives -1', () {
      expect(ContactMatcher.bestIndex(entries, 'Jose Nunez'), 3);
      expect(ContactMatcher.bestIndex(entries, '  '), -1);
      expect(ContactMatcher.bestIndex(entries, 'Zed'), -1);
    });
  });

  late FakeMemoryRepository repository;
  late FakeContactsService contacts;
  late Memory memory;
  final navigator = GlobalKey<NavigatorState>();

  setUp(() async {
    repository = FakeMemoryRepository();
    contacts = FakeContactsService(
      entries: [
        for (var i = 0; i < 40; i++)
          ContactEntry('k$i', 'Person ${i.toString().padLeft(2, '0')}'),
      ]..insert(30, const ContactEntry('ann', 'Ann Lee')),
    );
    final m = await repository.add(photoJpeg: [], capturedAt: DateTime(2026));
    memory = m.withField('name', 'Ann Lee');
    await repository.save(memory);
  });

  Finder inDialog(String text) => find.descendant(
    of: find.byType(ContactPickerDialog),
    matching: find.text(text),
  );

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

  testWidgets('first tap lists contacts at the best match; choosing links '
      'only its key', (tester) async {
    await showCard(tester);

    await tester.tap(find.byTooltip('Link to a contact'));
    await tester.pumpAndSettle();

    expect(find.byType(ContactPickerDialog), findsOneWidget);
    expect(inDialog('Ann Lee').hitTestable(), findsOneWidget);
    expect(find.text('Person 00'), findsNothing); // scrolled past the top
    await tester.tap(inDialog('Ann Lee'));
    await tester.pumpAndSettle();

    expect(repository.contactLinks, [(memory.id, 'ann')]);
    final json = repository.stored[memory.id]!.toJson();
    expect(json['contactKey'], 'ann');
    expect(json.toString().contains('Person'), isFalse);
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
    await tester.tap(find.text('Re-assign contact'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Person 31'));
    await tester.pumpAndSettle();
    expect(repository.stored[memory.id]!.contactKey, 'k31');
  });

  testWidgets('without permission the phone picker is used; backing out '
      'changes nothing', (tester) async {
    contacts.access = false;
    await showCard(tester);

    await tester.tap(find.byTooltip('Link to a contact'));
    await tester.pumpAndSettle();
    expect(contacts.calls, ['ensureAccess', 'pick']);
    expect(repository.contactLinks, isEmpty);

    contacts.systemPick = 'picked';
    await tester.tap(find.byTooltip('Link to a contact'));
    await tester.pumpAndSettle();
    expect(repository.stored[memory.id]!.contactKey, 'picked');
  });

  testWidgets('taps while a call is in flight are ignored; a late answer '
      'after leaving links nothing', (tester) async {
    contacts.accessGate = Completer<void>();
    await showCard(tester);

    await tester.tap(find.byTooltip('Link to a contact'));
    await tester.pump();
    await tester.tap(find.byTooltip('Link to a contact'));
    await tester.pump();
    expect(contacts.calls, ['ensureAccess']);

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    contacts.accessGate!.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(repository.contactLinks, isEmpty);
    expect(find.byType(ContactPickerDialog), findsNothing);
  });

  testWidgets('a name autosave after linking keeps the link', (tester) async {
    await showCard(tester);
    await tester.tap(find.byTooltip('Link to a contact'));
    await tester.pumpAndSettle();
    await tester.tap(inDialog('Ann Lee'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
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
