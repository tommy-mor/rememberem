import 'contact_entry.dart';

/// Finds the contact most likely to be a person, by name, to start the
/// link dialog there. Best effort: exact names first, then the same words
/// in any order ("Lee, Ann" for "Ann Lee"), then a prefix, then the most
/// words in common. Case and common accents are ignored.
class ContactMatcher {
  const ContactMatcher._();

  /// The index in [entries] of the best match for [name], or -1.
  static int bestIndex(List<ContactEntry> entries, String name) {
    final wanted = _fold(name);
    if (wanted.isEmpty) return -1;
    final wantedWords = _words(wanted);
    var best = -1;
    var bestScore = 0;
    for (final (i, entry) in entries.indexed) {
      final score = _score(_fold(entry.name), wanted, wantedWords);
      if (score > bestScore) {
        best = i;
        bestScore = score;
      }
    }
    return best;
  }

  static int _score(String candidate, String wanted, Set<String> wantedWords) {
    if (candidate == wanted) return 1000;
    if (candidate.startsWith(wanted)) return 800;
    // Word tiers only when there are words: no words must never match all.
    final words = _words(candidate);
    if (words.isEmpty || wantedWords.isEmpty) return 0;
    if (words.length == wantedWords.length && words.containsAll(wantedWords)) {
      return 900;
    }
    return words.intersection(wantedWords).length * 100;
  }

  static Set<String> _words(String folded) =>
      // Letters and digits of any script, so non-Latin names have words too.
      folded
          .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
          .where((w) => w.isNotEmpty)
          .toSet();

  static const _accents = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', //
    'ç': 'c', 'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', //
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ñ': 'n', //
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ø': 'o', //
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ý': 'y', 'ÿ': 'y',
  };

  static String _fold(String s) =>
      [for (final ch in s.trim().toLowerCase().split('')) _accents[ch] ?? ch]
          .join();
}
