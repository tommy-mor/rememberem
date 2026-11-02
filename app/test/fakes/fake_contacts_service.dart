import 'dart:async';

import 'package:rememberem/src/contacts/contact_entry.dart';
import 'package:rememberem/src/contacts/contact_open_result.dart';
import 'package:rememberem/src/contacts/contacts_service.dart';

/// Contacts for tests. Records every call; never writes anything.
class FakeContactsService implements ContactsService {
  FakeContactsService({this.entries = const [], this.access = true});

  List<ContactEntry> entries;
  bool access;

  /// When set, [ensureAccess] waits for it (a slow permission prompt).
  Completer<void>? accessGate;
  String? systemPick;
  ContactOpenResult openResult = ContactOpenResult.opened;
  final List<String> calls = [];

  @override
  Future<bool> ensureAccess() async {
    calls.add('ensureAccess');
    await accessGate?.future;
    return access;
  }

  @override
  Future<List<ContactEntry>> list() async {
    calls.add('list');
    return entries;
  }

  @override
  Future<String?> pickWithSystemPicker() async {
    calls.add('pick');
    return systemPick;
  }

  @override
  Future<ContactOpenResult> open(String key) async {
    calls.add('open $key');
    return openResult;
  }
}
