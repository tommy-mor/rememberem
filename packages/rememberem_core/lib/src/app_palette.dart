/// The colours Fred can choose from in Settings, as ARGB values. The first
/// of each list is the default.
class AppPalette {
  const AppPalette._();

  /// App bars and buttons. Navy is the logo's.
  static const themeColors = [
    0xFF0A2A7A, // navy
    0xFF005B4F, // teal
    0xFF1B5E20, // forest
    0xFF6A1B9A, // plum
    0xFF8E2430, // burgundy
    0xFF8F3A1C, // rust
    0xFF37474F, // slate
  ];

  /// Page backgrounds: light ones (light blue has the logo's hue), then
  /// dark ones, which make the whole app dark.
  static const backgrounds = [
    0xFFD3DEFA, // light blue
    0xFFFFFFFF, // white
    0xFFFCEFC7, // cream
    0xFFCDEEDB, // mint
    0xFFE2D3F7, // lavender
    0xFFF8D5D9, // blush
    0xFFE1E5EA, // pearl
    ...darkBackgrounds,
  ];

  static const darkBackgrounds = [
    0xFF0F1B33, // midnight
    0xFF1E2023, // charcoal
    0xFF10291F, // pine
    0xFF261631, // aubergine
  ];

  static bool isDark(int background) => darkBackgrounds.contains(background);

  /// The paler backgrounds of earlier versions, each with its new tint,
  /// so a saved choice keeps its colour's name.
  static const legacyBackgrounds = {
    0xFFE9EEFC: 0xFFD3DEFA,
    0xFFFFF8E7: 0xFFFCEFC7,
    0xFFE8F5EE: 0xFFCDEEDB,
    0xFFF1EAFB: 0xFFE2D3F7,
    0xFFFCEDEE: 0xFFF8D5D9,
    0xFFF1F3F5: 0xFFE1E5EA,
  };

  /// Theme colours of earlier versions (teal, forest, rust), darkened so
  /// text in them reads on every background.
  static const legacyThemeColors = {
    0xFF00695C: 0xFF005B4F,
    0xFF2E7D32: 0xFF1B5E20,
    0xFFB4532A: 0xFF8F3A1C,
  };

  /// What each colour is called, for screen readers and tooltips.
  static const names = {
    0xFF0A2A7A: 'Navy',
    0xFF005B4F: 'Teal',
    0xFF1B5E20: 'Forest',
    0xFF6A1B9A: 'Plum',
    0xFF8E2430: 'Burgundy',
    0xFF8F3A1C: 'Rust',
    0xFF37474F: 'Slate',
    0xFFD3DEFA: 'Light blue',
    0xFFFFFFFF: 'White',
    0xFFFCEFC7: 'Cream',
    0xFFCDEEDB: 'Mint',
    0xFFE2D3F7: 'Lavender',
    0xFFF8D5D9: 'Blush',
    0xFFE1E5EA: 'Pearl',
    0xFF0F1B33: 'Midnight',
    0xFF1E2023: 'Charcoal',
    0xFF10291F: 'Pine',
    0xFF261631: 'Aubergine',
  };
}
