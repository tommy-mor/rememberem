/// Joins a recogniser's results into one transcript. On-device
/// recognisers send each spoken stretch as its own result after a pause,
/// starting again from nothing, so a result that does not carry on from
/// the last one starts a new segment instead of replacing what was heard.
class SpeechTranscript {
  final _segments = <String>[];
  String _current = '';
  bool _currentFinal = false;

  /// Everything heard so far, after taking in [words], the recogniser's
  /// latest result; [isFinal] if the recogniser said that stretch ended.
  String add(String words, {bool isFinal = false}) {
    final next = words.trim();
    // An empty result, or a final one sent twice, adds nothing.
    if (next.isEmpty || (_currentFinal && next == _current)) return text;
    if (_current.isNotEmpty && (_currentFinal || _startsOver(next))) {
      _segments.add(_current);
    }
    _current = next;
    _currentFinal = isFinal;
    return text;
  }

  String get text =>
      [..._segments, _current].where((s) => s.isNotEmpty).join(' ');

  /// A recogniser revising its guess keeps how it began: at least half the
  /// words of the shorter guess open both. Anything else is a new stretch
  /// ("she works at the library", then "she has a cat"). Taking a revision
  /// for a new stretch repeats words Fred can delete; the other way round
  /// would lose what he said.
  bool _startsOver(String next) {
    final was = _current.toLowerCase();
    final now = next.toLowerCase();
    if (was.startsWith(now) || now.startsWith(was)) return false;
    final a = _words(was);
    final b = _words(now);
    final shorter = a.length < b.length ? a.length : b.length;
    var shared = 0;
    while (shared < shorter && a[shared] == b[shared]) {
      shared++;
    }
    return shared == 0 || shared * 2 < shorter;
  }

  static List<String> _words(String s) => s.split(RegExp(r'\s+'));
}
