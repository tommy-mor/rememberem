/// What happened when Fred asked to see a linked contact.
enum ContactOpenResult {
  opened,

  /// The contact has been deleted from the phone.
  notFound,

  /// There is no contacts app to show it.
  noApp,
}
