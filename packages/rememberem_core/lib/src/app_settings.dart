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

    bool flag(String key) {
      final value = json[key];
      return value is bool ? value : true;
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
    );
  }

  static const defaultPlaceRadiusFeet = 300;
  static const defaultMeetingWindowMinutes = 120;
  static const defaultGameTurns = 10;
  static const defaultRevealSeconds = 3;

  static const placeRadiusRange = (min: 100, max: 1000);
  static const meetingWindowRange = (min: 30, max: 240);
  static const gameTurnsRange = (min: 5, max: 20);
  static const revealSecondsRange = (min: 1, max: 5);
  static const rememberedThresholdRange = (min: 3, max: 10);

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
      other.streetMaps == streetMaps;

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
      );
}
