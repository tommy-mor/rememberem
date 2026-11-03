import 'dart:async';

import 'package:rememberem/src/contacts/contact_open_result.dart';
import 'package:rememberem/src/contacts/contacts_service.dart';

/// Contacts for tests. Records every call; never writes anything.
class FakeContactsService implements ContactsService {
  /// When set, [pick] waits for it (Fred still choosing).
  Completer<void>? pickGate;
  String? systemPick;
  ContactOpenResult openResult = ContactOpenResult.opened;
  final List<String> calls = [];

  @override
  Future<String?> pick() async {
    calls.add('pick');
    await pickGate?.future;
    return systemPick;
  }

  @override
  Future<ContactOpenResult> open(String key) async {
    calls.add('open $key');
    return openResult;
  }
}
