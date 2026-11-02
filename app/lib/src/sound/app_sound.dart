/// The short sounds the app plays, made by tool/make_sounds.py.
enum AppSound {
  right('sounds/right.wav'),
  wrong('sounds/wrong.wav'),
  listenStart('sounds/listen_start.wav'),
  listenStop('sounds/listen_stop.wav');

  const AppSound(this.asset);

  /// The asset path, relative to assets/.
  final String asset;
}
