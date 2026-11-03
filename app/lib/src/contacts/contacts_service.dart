import 'contact_open_result.dart';

/// The phone's contacts, as far as linking people needs. Rememberem never
/// reads the contact list, so it needs no contacts permission.
abstract interface class ContactsService {
  /// The phone's own contact picker. The chosen contact's key, or null if
  /// Fred backed out.
  Future<String?> pick();

  /// Shows contact [key] in the phone's contacts app.
  Future<ContactOpenResult> open(String key);
}
