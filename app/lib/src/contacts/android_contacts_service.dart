import 'package:flutter/services.dart';

import 'contact_open_result.dart';
import 'contacts_service.dart';

/// [ContactsService] through the app's own channel (ContactsChannel.kt).
class AndroidContactsService implements ContactsService {
  static const _channel = MethodChannel('com.rememberem.rememberem/contacts');

  @override
  Future<String?> pick() => _channel.invokeMethod<String>('pick');

  @override
  Future<ContactOpenResult> open(String key) async {
    final result = await _channel.invokeMethod<String>('open', {'key': key});
    return ContactOpenResult.values.firstWhere(
      (r) => r.name == result,
      orElse: () => ContactOpenResult.noApp,
    );
  }
}
