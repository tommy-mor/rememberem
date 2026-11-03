/// Whether the phone lets Rememberem notice Fred arriving at places, or
/// the first thing still missing.
enum PlaceAlertAccess {
  granted,

  /// Notifications are blocked for the app.
  notifications,

  /// Precise location is not allowed (or only approximate).
  location,

  /// Location is allowed only while the app is open, not "all the time".
  background,
}
