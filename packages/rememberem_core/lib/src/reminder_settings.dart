/// Whether Fred wants a daily practice reminder, and at what local time,
/// whether he wants anniversary notices, and whether place notices (which
/// use location in the background, so are off until he turns them on).
class ReminderSettings {
  const ReminderSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
    this.anniversaries = true,
    this.places = false,
  });

  /// Off, at 19:00 if turned on.
  const ReminderSettings.off()
      : enabled = false,
        hour = 19,
        minute = 0,
        anniversaries = false,
        places = false;

  /// On at 19:00: what a fresh install starts with (nothing saved yet).
  const ReminderSettings.defaults()
      : enabled = true,
        hour = 19,
        minute = 0,
        anniversaries = true,
        places = false;

  /// Anything unreadable means [ReminderSettings.off]: a damaged file
  /// never turns reminders on or asks for permission again.
  factory ReminderSettings.fromJson(Object? json) {
    if (json is! Map) return const ReminderSettings.off();
    final enabled = json['enabled'];
    final hour = json['hour'];
    final minute = json['minute'];
    // Before anniversary notices: they follow the practice switch, so no
    // one who turned reminders off is notified without asking.
    final anniversaries = json['anniversaries'] ?? enabled;
    // Missing (older files) or damaged: off. Only Fred turns it on.
    final places = json['places'] == true;
    if (enabled is! bool ||
        hour is! int ||
        minute is! int ||
        anniversaries is! bool ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return const ReminderSettings.off();
    }
    return ReminderSettings(
      enabled: enabled,
      hour: hour,
      minute: minute,
      anniversaries: anniversaries,
      places: places,
    );
  }

  final bool enabled;
  final int hour;
  final int minute;

  /// A morning notice on each day with an anniversary in the coming week.
  final bool anniversaries;

  /// A notice on arriving where Fred has met people.
  final bool places;

  ReminderSettings copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    bool? anniversaries,
    bool? places,
  }) =>
      ReminderSettings(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        anniversaries: anniversaries ?? this.anniversaries,
        places: places ?? this.places,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'hour': hour,
        'minute': minute,
        'anniversaries': anniversaries,
        'places': places,
      };

  @override
  bool operator ==(Object other) =>
      other is ReminderSettings &&
      other.enabled == enabled &&
      other.hour == hour &&
      other.minute == minute &&
      other.anniversaries == anniversaries &&
      other.places == places;

  @override
  int get hashCode => Object.hash(enabled, hour, minute, anniversaries, places);
}
