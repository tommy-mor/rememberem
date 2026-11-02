/// Opens a web page outside the app.
abstract interface class LinkOpener {
  /// Opens [url] in the browser; false if nothing could open it.
  Future<bool> open(Uri url);
}
