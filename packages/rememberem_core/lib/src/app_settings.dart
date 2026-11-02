import 'app_palette.dart';
import 'meeting_finder.dart';
import 'place_finder.dart';
import 'remembered_count.dart';

/// Fred's choices for how the app behaves. Reminders keep their own
/// settings ([ReminderSettings]).
class AppSettings {
  const AppSettings({
    this.placeRadiusFeet = defaultPlaceRadiusFeet,
    this.meetingWindowMinutes = defaultMeetingWindowMinutes,
    this.gameTurns = defaultGameTurns,
    this.revealSeconds = defaultRevealSeconds,
    this.rememberedThreshold = RememberedCount.defaultThreshold,
    this.sounds = true,
    this.vibration = true,
    this.streetMaps = true,
    this.detailTextPercent = defaultDetailTextPercent,
    this.themeColor = defaultThemeColor,
    this.backgroundColor = defaultBackgroundColor,
    this.darkMode = false,
  });

  /// Reads what [toJson] wrote. Never throws: a missing, mistyped or
  /// out-of-range value takes its default, and numbers are clamped.
  factory AppSettings.fromJson(Object? json) {
    if (json is! Map) return const AppSettings();
    int number(String key, int fallback, ({int min, int max}) range) {
      final value = json[key];
      if (value is! num || !value.isFinite) return fallback;
      return value.round().clamp(range.min, range.max);
    }

    bool flag(String key, {bool fallback = true}) {
      final value = json[key];
      return value is bool ? value : fallback;
    }

    int colour(String key, List<int> palette) {
      final value = json[key];
      return value is int && palette.contains(value) ? value : palette.first;
    }

    return AppSettings(
      placeRadiusFeet: number(
        'placeRadiusFeet',
        defaultPlaceRadiusFeet,
        placeRadiusRange,
      ),
      meetingWindowMinutes: number(
        'meetingWindowMinutes',
        defaultMeetingWindowMinutes,
        meetingWindowRange,
      ),
      gameTurns: number('gameTurns', defaultGameTurns, gameTurnsRange),
      revealSeconds: number(
        'revealSeconds',
        defaultRevealSeconds,
        revealSecondsRange,
      ),
      rememberedThreshold: number(
        'rememberedThreshold',
        RememberedCount.defaultThreshold,
        rememberedThresholdRange,
      ),
      sounds: flag('sounds'),
      vibration: flag('vibration'),
      streetMaps: flag('streetMaps'),
      detailTextPercent: number(
        'detailTextPercent',
        defaultDetailTextPercent,
        detailTextPercentRange,
      ),
      themeColor: colour('themeColor', AppPalette.themeColors),
      backgroundColor: colour('backgroundColor', AppPalette.backgrounds),
      darkMode: flag('darkMode', fallback: false),
    );
  }

  static const defaultPlaceRadiusFeet = 555;
  static const defaultMeetingWindowMinutes = 120;
  static const defaultGameTurns = 10;
  static const defaultRevealSeconds = 3;
  static const defaultDetailTextPercent = 80;
  static const defaultThemeColor = 0xFF0A2A7A; // AppPalette.themeColors.first
  static const defaultBackgroundColor =
      0xFFE9EEFC; // AppPalette.backgrounds.first

  static const placeRadiusRange = (min: 100, max: 1000);
  static const meetingWindowRange = (min: 30, max: 240);
  static const gameTurnsRange = (min: 5, max: 20);
  static const revealSecondsRange = (min: 1, max: 5);
  static const rememberedThresholdRange = (min: 3, max: 10);
  static const detailTextPercentRange = (min: 60, max: 150);

  static const _metersPerFoot = 0.3048;

  /// How near a known place must be to fill in the place of a new photo.
  final int placeRadiusFeet;

  /// How close in time of week a meeting must be to be suggested.
  final int meetingWindowMinutes;

  /// Questions per practice game (fewer if there is not enough to ask).
  final int gameTurns;

  /// How long a face or detail shows before the choices appear.
  final int revealSeconds;

  /// Right answers in a row before a face or detail counts as remembered.
  final int rememberedThreshold;

  final bool sounds;
  final bool vibration;

  /// Whether maps fetch street tiles from OpenStreetMap.
  final bool streetMaps;

  /// The size of detail text, as a percentage of normal (on top of the
  /// phone's own text size).
  final int detailTextPercent;

  /// App bars and buttons, from [AppPalette.themeColors].
  final int themeColor;

  /// The page background in light mode, from [AppPalette.backgrounds].
  final int backgroundColor;

  /// Dark pages; the background choice then does not apply.
  final bool darkMode;

  PlaceFinder get placeFinder =>
      PlaceFinder(radiusMeters: placeRadiusFeet * _metersPerFoot);

  MeetingFinder get meetingFinder =>
      MeetingFinder(window: Duration(minutes: meetingWindowMinutes));

  Duration get reveal => Duration(seconds: revealSeconds);

  AppSettings copyWith({
    int? placeRadiusFeet,
    int? meetingWindowMinutes,
    int? gameTurns,
    int? revealSeconds,
    int? rememberedThreshold,
    bool? sounds,
    bool? vibration,
    bool? streetMaps,
    int? detailTextPercent,
    int? themeColor,
    int? backgroundColor,
    bool? darkMode,
  }) =>
      AppSettings(
        placeRadiusFeet: placeRadiusFeet ?? this.placeRadiusFeet,
        meetingWindowMinutes: meetingWindowMinutes ?? this.meetingWindowMinutes,
        gameTurns: gameTurns ?? this.gameTurns,
        revealSeconds: revealSeconds ?? this.revealSeconds,
        rememberedThreshold: rememberedThreshold ?? this.rememberedThreshold,
        sounds: sounds ?? this.sounds,
        vibration: vibration ?? this.vibration,
        streetMaps: streetMaps ?? this.streetMaps,
        detailTextPercent: detailTextPercent ?? this.detailTextPercent,
        themeColor: themeColor ?? this.themeColor,
        backgroundColor: backgroundColor ?? this.backgroundColor,
        darkMode: darkMode ?? this.darkMode,
      );

  Map<String, dynamic> toJson() => {
        'placeRadiusFeet': placeRadiusFeet,
        'meetingWindowMinutes': meetingWindowMinutes,
        'gameTurns': gameTurns,
        'revealSeconds': revealSeconds,
        'rememberedThreshold': rememberedThreshold,
        'sounds': sounds,
        'vibration': vibration,
        'streetMaps': streetMaps,
        'detailTextPercent': detailTextPercent,
        'themeColor': themeColor,
        'backgroundColor': backgroundColor,
        'darkMode': darkMode,
      };

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.placeRadiusFeet == placeRadiusFeet &&
      other.meetingWindowMinutes == meetingWindowMinutes &&
      other.gameTurns == gameTurns &&
      other.revealSeconds == revealSeconds &&
      other.rememberedThreshold == rememberedThreshold &&
      other.sounds == sounds &&
      other.vibration == vibration &&
      other.streetMaps == streetMaps &&
      other.detailTextPercent == detailTextPercent &&
      other.themeColor == themeColor &&
      other.backgroundColor == backgroundColor &&
      other.darkMode == darkMode;

  @override
  int get hashCode => Object.hash(
        placeRadiusFeet,
        meetingWindowMinutes,
        gameTurns,
        revealSeconds,
        rememberedThreshold,
        sounds,
        vibration,
        streetMaps,
        detailTextPercent,
        themeColor,
        backgroundColor,
        darkMode,
      );
}
