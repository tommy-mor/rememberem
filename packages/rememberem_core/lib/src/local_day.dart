/// A calendar day in local time, so 23:30 belongs to its own day wherever
/// the time was stored as UTC.
class LocalDay implements Comparable<LocalDay> {
  const LocalDay(this.year, this.month, this.day);

  factory LocalDay.of(DateTime time) {
    final local = time.toLocal();
    return LocalDay(local.year, local.month, local.day);
  }

  final int year;
  final int month;
  final int day;

  /// Local midnight at the start of this day.
  DateTime toDate() => DateTime(year, month, day);

  @override
  int compareTo(LocalDay other) => toDate().compareTo(other.toDate());

  @override
  bool operator ==(Object other) =>
      other is LocalDay &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => 'LocalDay($year-$month-$day)';
}
