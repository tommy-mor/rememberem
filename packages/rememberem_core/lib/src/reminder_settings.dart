/// Whether Fred wants a daily practice reminder, and at what local time.
class ReminderSettings {
  const ReminderSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  /// Off, at 19:00 if turned on.
  const ReminderSettings.off()
      : enabled = false,
        hour = 19,
        minute = 0;

  /// On at 19:00: what a fresh install starts with (nothing saved yet).
  const ReminderSettings.defaults()
      : enabled = true,
        hour = 19,
        minute = 0;

  /// Anything unreadable means [ReminderSettings.off]: a damaged file
  /// never turns reminders on or asks for permission again.
  factory ReminderSettings.fromJson(Object? json) {
    if (json is! Map) return const ReminderSettings.off();
    final enabled = json['enabled'];
    final hour = json['hour'];
    final minute = json['minute'];
    if (enabled is! bool ||
        hour is! int ||
        minute is! int ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return const ReminderSettings.off();
    }
    return ReminderSettings(enabled: enabled, hour: hour, minute: minute);
  }

  final bool enabled;
  final int hour;
  final int minute;

  ReminderSettings copyWith({bool? enabled, int? hour, int? minute}) =>
      ReminderSettings(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'hour': hour,
        'minute': minute,
      };

  @override
  bool operator ==(Object other) =>
      other is ReminderSettings &&
      other.enabled == enabled &&
      other.hour == hour &&
      other.minute == minute;

  @override
  int get hashCode => Object.hash(enabled, hour, minute);
}
