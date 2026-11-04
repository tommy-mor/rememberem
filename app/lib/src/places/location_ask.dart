/// How asking for location all the time went.
enum LocationAsk {
  granted,

  /// The app's settings page is open for Fred to choose "Allow all the
  /// time"; place notices finish turning on when he comes back.
  inSettings,
  refused,
}
