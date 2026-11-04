import 'package:rememberem_core/rememberem_core.dart';
import 'package:test/test.dart';

void main() {
  test('defaults match the constants the app used before settings', () {
    const s = AppSettings();
    expect(s.placeFinder.radiusMeters,
        closeTo(PlaceFinder.defaultRadiusMeters, 1e-9));
    expect(s.meetingFinder.window, MeetingFinder.defaultWindow);
    expect(s.gameTurns, 10);
    expect(s.reveal, const Duration(seconds: 3));
    expect(s.rememberedThreshold, RememberedCount.defaultThreshold);
    expect([s.sounds, s.vibration, s.streetMaps], [true, true, true]);
    expect(s.placeRadiusFeet, 555);
    expect(s.detailTextPercent, 80);
    expect(s.themeColor, AppPalette.themeColors.first);
    expect(s.backgroundColor, AppPalette.backgrounds.first);
    expect(s.darkMode, isFalse);
  });

  test('a settings file from before display settings keeps light mode', () {
    final s = AppSettings.fromJson({'sounds': false, 'placeRadiusFeet': 300});
    expect(s.darkMode, isFalse);
    expect(s.placeRadiusFeet, 300);
    expect(s.detailTextPercent, 80);
    expect(s.backgroundColor, AppPalette.backgrounds.first);
  });

  test('colours outside the palette fall back; text size is clamped', () {
    final s = AppSettings.fromJson({
      'themeColor': 0xFF123456,
      'backgroundColor': 'blue',
      'detailTextPercent': 500,
      'darkMode': 'yes',
    });
    expect(s.themeColor, AppPalette.themeColors.first);
    expect(s.backgroundColor, AppPalette.backgrounds.first);
    expect(s.detailTextPercent, 150);
    expect(s.darkMode, isFalse);
  });

  test('round-trips through json', () {
    const s = AppSettings(
      placeRadiusFeet: 500,
      meetingWindowMinutes: 45,
      gameTurns: 7,
      revealSeconds: 2,
      rememberedThreshold: 8,
      sounds: false,
      vibration: false,
      streetMaps: false,
      detailTextPercent: 110,
      themeColor: 0xFF005B4F,
      backgroundColor: 0xFFFFFFFF,
      darkMode: true,
    );
    expect(AppSettings.fromJson(s.toJson()), s);
  });

  test('garbage of any shape gives the defaults, never a throw', () {
    for (final bad in <Object?>[null, 'x', 3, [], <String, dynamic>{}]) {
      expect(AppSettings.fromJson(bad), const AppSettings(), reason: '$bad');
    }
    expect(
      AppSettings.fromJson({
        'gameTurns': 'ten',
        'revealSeconds': double.nan,
        'placeRadiusFeet': double.infinity,
        'sounds': 'no',
      }),
      const AppSettings(),
    );
  });

  test('numbers are rounded and clamped to their ranges', () {
    final s = AppSettings.fromJson({
      'placeRadiusFeet': 1e12,
      'meetingWindowMinutes': -5,
      'gameTurns': 6.6,
      'revealSeconds': 99,
      'rememberedThreshold': 0,
    });
    expect(s.placeRadiusFeet, 1000);
    expect(s.meetingWindowMinutes, 30);
    expect(s.gameTurns, 7);
    expect(s.revealSeconds, 10);
    expect(s.rememberedThreshold, 3);
  });

  test('the remembered threshold is a parameter', () {
    final p = Memory(id: 'p', encounters: [
      Encounter(photoFileName: 'p.jpg', capturedAt: DateTime(2026)),
    ]).withScore(4, DateTime(2026));
    expect(RememberedCount.of([p]).faces, 0);
    expect(RememberedCount.of([p], threshold: 3).faces, 1);
  });

  test('reminders default on at 19:00, but damage still means off', () {
    expect(const ReminderSettings.defaults().enabled, isTrue);
    expect(ReminderSettings.fromJson('junk').enabled, isFalse);
  });

  test('the show delay is on unless turned off, and round-trips', () {
    expect(AppSettings.fromJson({}).revealDelay, isTrue);
    const off = AppSettings(revealDelay: false);
    expect(AppSettings.fromJson(off.toJson()), off);
    expect(off, isNot(const AppSettings()));
    expect(off.copyWith(revealDelay: true), const AppSettings());
  });

  test('an older, paler background keeps its name; dark ones make dark pages',
      () {
    final old = AppSettings.fromJson({'backgroundColor': 0xFFFFF8E7});
    expect(old.backgroundColor, 0xFFFCEFC7); // cream, deeper
    expect(AppPalette.names[old.backgroundColor], 'Cream');
    expect(old.darkPages, isFalse);
    for (final dark in AppPalette.darkBackgrounds) {
      final s = AppSettings.fromJson({'backgroundColor': dark});
      expect(s.backgroundColor, dark);
      expect(s.darkPages, isTrue);
    }
    expect(const AppSettings(darkMode: true).darkPages, isTrue);
    for (final c in [...AppPalette.backgrounds, ...AppPalette.themeColors]) {
      expect(AppPalette.names[c], isNotNull);
    }
  });
}
