/// The colours Fred can choose from in Settings, as ARGB values. The first
/// of each list is the default.
class AppPalette {
  const AppPalette._();

  /// App bars and buttons. Navy is the logo's.
  static const themeColors = [
    0xFF0A2A7A, // navy
    0xFF00695C, // teal
    0xFF2E7D32, // forest
    0xFF6A1B9A, // plum
    0xFF8E2430, // burgundy
    0xFFB4532A, // rust
    0xFF37474F, // slate
  ];

  /// Page backgrounds in light mode. Light blue has the logo's hue.
  static const backgrounds = [
    0xFFE9EEFC, // light blue
    0xFFFFFFFF, // white
    0xFFFFF8E7, // cream
    0xFFE8F5EE, // mint
    0xFFF1EAFB, // lavender
    0xFFFCEDEE, // blush
    0xFFF1F3F5, // pearl
  ];

  /// What each colour is called, for screen readers and tooltips.
  static const names = {
    0xFF0A2A7A: 'Navy',
    0xFF00695C: 'Teal',
    0xFF2E7D32: 'Forest',
    0xFF6A1B9A: 'Plum',
    0xFF8E2430: 'Burgundy',
    0xFFB4532A: 'Rust',
    0xFF37474F: 'Slate',
    0xFFE9EEFC: 'Light blue',
    0xFFFFFFFF: 'White',
    0xFFFFF8E7: 'Cream',
    0xFFE8F5EE: 'Mint',
    0xFFF1EAFB: 'Lavender',
    0xFFFCEDEE: 'Blush',
    0xFFF1F3F5: 'Pearl',
  };
}
