import 'contact_entry.dart';
import 'contact_open_result.dart';

/// The phone's contacts, read only, as far as linking people needs.
abstract interface class ContactsService {
  /// Whether contacts can be listed, asking Fred first if need be.
  Future<bool> ensureAccess();

  /// Every contact, A to Z. Needs [ensureAccess].
  Future<List<ContactEntry>> list();

  /// The phone's own contact picker, which needs no permission. The chosen
  /// contact's key, or null if Fred backed out.
  Future<String?> pickWithSystemPicker();

  /// Shows contact [key] in the phone's contacts app.
  Future<ContactOpenResult> open(String key);
}
