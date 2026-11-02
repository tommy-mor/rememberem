/// One phone contact as the link dialog needs it: an opaque key and the
/// name to show. Nothing else is read.
class ContactEntry {
  const ContactEntry(this.key, this.name);

  final String key;
  final String name;
}
